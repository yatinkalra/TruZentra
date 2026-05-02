/**
 * ZentraLoanSubmitService
 * @description Submits a loan restructuring request.
 *              Creates Loan_Restructuring_Request__c, updates
 *              FinServ__FinancialAccount__c, and creates an RM callback Task.
 * @developer   BlueForce Team
 * @date        2026-04-16
 */
public without sharing class ZentraLoanSubmitService {

    @InvocableMethod(label='Submit Loan Restructuring'
        description='Submits the selected restructuring option, creates a request record, updates the loan, and schedules an RM callback.'
        category='Loan Services')
    public static List<SubmitResult> submitRestructuring(List<SubmitRequest> requests) {
        List<SubmitResult> results = new List<SubmitResult>();

        for (SubmitRequest req : requests) {
            SubmitResult r = new SubmitResult();
            try {
                // Validate inputs
                if (req.loanAccountId == null || String.isBlank(req.selectedOption) || String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Loan Account Id, Selected Option (A/B/C), and Customer Id are required.';
                    results.add(r);
                    continue;
                }

                String option = req.selectedOption.trim().toUpperCase();
                if (option != 'A' && option != 'B' && option != 'C') {
                    r.success = false;
                    r.message = 'Invalid option. Please select A, B, or C.';
                    results.add(r);
                    continue;
                }

                // Fetch loan details
                FinServ__FinancialAccount__c loan = [
                    SELECT Id, FinServ__PrincipalBalance__c, Current_EMI__c,
                           FinServ__LoanTermMonths__c, FinServ__InterestRate__c,
                           Is_Restructured__c, Last_Restructure_Date__c,
                           FinServ__FinancialAccountType__c
                    FROM FinServ__FinancialAccount__c
                    WHERE Id = :req.loanAccountId
                    LIMIT 1
                ];

                // Check 90-day cooldown — based on existing restructuring requests
                List<Loan_Restructuring_Request__c> recentRequests = [
                    SELECT Id, CreatedDate FROM Loan_Restructuring_Request__c
                    WHERE Loan_Financial_Account__c = :loan.Id
                      AND Status__c = 'Submitted'
                      AND CreatedDate >= :DateTime.newInstance(Date.today().addDays(-90), Time.newInstance(0,0,0,0))
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!recentRequests.isEmpty()) {
                    Date lastSubmitDate = recentRequests[0].CreatedDate.date();
                    r.success = false;
                    r.message = 'This loan was restructured within the last 90 days. Please try again after ' +
                        lastSubmitDate.addDays(90).format() + '.';
                    results.add(r);
                    continue;
                }

                Decimal principal = loan.FinServ__PrincipalBalance__c;
                Decimal annualRate = loan.FinServ__InterestRate__c;
                Integer currentTenure = Integer.valueOf(loan.FinServ__LoanTermMonths__c);
                Decimal currentEMI = loan.Current_EMI__c;

                // Calculate based on selected option
                Integer newTenure;
                Decimal newEMI;
                Decimal additionalInterest;

                if (option == 'A') {
                    newTenure = currentTenure + 12;
                    newEMI = ZentraLoanSimulateService.calculateEMI(principal, annualRate, newTenure);
                    additionalInterest = ((newEMI * newTenure) - principal) - ((currentEMI * currentTenure) - principal);
                } else if (option == 'B') {
                    newTenure = currentTenure + 24;
                    newEMI = ZentraLoanSimulateService.calculateEMI(principal, annualRate, newTenure);
                    additionalInterest = ((newEMI * newTenure) - principal) - ((currentEMI * currentTenure) - principal);
                } else {
                    // Option C: 3-month moratorium
                    newTenure = currentTenure; // Tenure unchanged
                    newEMI = currentEMI; // EMI unchanged after moratorium
                    Decimal monthlyRate = annualRate / 12 / 100;
                    additionalInterest = (principal * monthlyRate) * 3;
                }

                // Create Loan_Restructuring_Request__c
                Loan_Restructuring_Request__c lrr = new Loan_Restructuring_Request__c(
                    Loan_Financial_Account__c = loan.Id,
                    Customer__c = req.customerId,
                    Selected_Option__c = option,
                    New_EMI__c = newEMI,
                    New_Tenure_Months__c = newTenure,
                    Additional_Interest__c = additionalInterest.abs(),
                    Original_EMI__c = currentEMI,
                    OTP_Confirmed__c = true,
                    Status__c = 'Submitted'
                );
                insert lrr;
                lrr = [SELECT Id, Name FROM Loan_Restructuring_Request__c WHERE Id = :lrr.Id];

                // Update FinServ__FinancialAccount__c via system-context helper
                // (bypasses FSC PSL validation that blocks guest/service users)
                try {
                    ZentraSystemDMLHelper.updateLoanAfterRestructuring(
                        loan.Id, option, newTenure, newEMI
                    );
                } catch (Exception loanEx) {
                    // Log but do not fail — request was already created
                    ZentraErrorLogger.log('ZentraLoanSubmitService', 'updateLoanAccount', loanEx, req.customerId != null ? Id.valueOf(req.customerId) : null);
                }

                // Create RM callback Task — linked to the restructuring request
                Task rmTask = new Task(
                    Subject = 'RM Callback — Loan Restructuring ' + lrr.Name,
                    Description = 'Customer has submitted a loan restructuring request (Option ' + option + ') for ' + loan.FinServ__FinancialAccountType__c + '. ' +
                        'New EMI: ₹' + String.valueOf(newEMI.setScale(2)) + '. Please call to confirm.\n' +
                        'Request: ' + lrr.Name + '\nLoan Account: ' + loan.Id,
                    WhatId = lrr.Id,
                    WhoId = getContactId(req.customerId),
                    ActivityDate = Date.today().addDays(1),
                    Priority = 'High',
                    Status = 'Not Started'
                );
                insert rmTask;

                // Build success response
                r.success = true;
                r.requestId = lrr.Id;
                r.requestNumber = lrr.Name;
                r.message = '✅ Your loan restructuring request has been submitted successfully!\n\n' +
                    '📋 Request Number: ' + lrr.Name + '\n' +
                    '📌 Selected Option: ' + getOptionLabel(option) + '\n' +
                    '💰 New EMI: ₹' + String.valueOf(newEMI.setScale(2)) + '/month\n' +
                    '📅 New Tenure: ' + newTenure + ' months\n' +
                    '💵 Monthly Savings: ₹' + String.valueOf((currentEMI - newEMI).setScale(2)) + '\n\n' +
                    '📞 A Relationship Manager will call you within 24 hours to finalize.\n' +
                    '📧 A confirmation email with all the details has been sent to your registered email address.\n' +
                    'Thank you for choosing Zentra Bank!';

                // Send confirmation email
                ZentraEmailService.sendLoanRestructuringEmail(
                    req.customerId,
                    lrr.Name,
                    loan.FinServ__FinancialAccountType__c,
                    getOptionLabel(option),
                    currentEMI,
                    newEMI,
                    newTenure,
                    currentEMI - newEMI
                );

            } catch (QueryException qe) {
                ZentraErrorLogger.log('ZentraLoanSubmitService', 'submitRestructuring', qe, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Loan account not found.';
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraLoanSubmitService', 'submitRestructuring', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Error submitting restructuring: ' + e.getMessage();
            }
            results.add(r);
        }
        return results;
    }

    private static Id getContactId(String accountId) {
        try {
            List<Contact> contacts = [SELECT Id FROM Contact WHERE AccountId = :accountId LIMIT 1];
            return contacts.isEmpty() ? null : contacts[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static String getOptionLabel(String option) {
        if (option == 'A') return 'A — Extend tenure by 1 year';
        if (option == 'B') return 'B — Extend tenure by 2 years';
        if (option == 'C') return 'C — 3-month moratorium';
        return option;
    }

    public class SubmitRequest {
        @InvocableVariable(label='Loan Account Id' description='FinServ__FinancialAccount__c loan record Id' required=true)
        public Id loanAccountId;

        @InvocableVariable(label='Selected Option' description='A, B, or C' required=true)
        public String selectedOption;

        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;
    }

    public class SubmitResult {
        @InvocableVariable(label='Success' description='Whether submission was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status/confirmation message')
        public String message;

        @InvocableVariable(label='Request Id' description='Loan_Restructuring_Request__c record Id')
        public Id requestId;

        @InvocableVariable(label='Request Number' description='Auto-number of the request (LR-0001)')
        public String requestNumber;
    }
}