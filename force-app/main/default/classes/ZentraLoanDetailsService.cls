/**
 * ZentraLoanDetailsService
 * @description Fetches loan account details for an authenticated customer.
 *              Queries FinServ__FinancialAccount__c where type is Loan Account,
 *              Auto Loan, or Mortgage.
 * @developer   BlueForce Team
 * @date        2026-04-16
 */
public without sharing class ZentraLoanDetailsService {

    private static final Set<String> LOAN_TYPES = new Set<String>{
        'Loan Account', 'Auto Loan', 'Mortgage'
    };

    @InvocableMethod(label='Get Loan Details'
        description='Returns loan account details for an authenticated customer including outstanding principal, EMI, tenure, and interest rate.'
        category='Loan Services')
    public static List<LoanDetailsResult> getLoanDetails(List<LoanDetailsRequest> requests) {
        List<LoanDetailsResult> results = new List<LoanDetailsResult>();

        for (LoanDetailsRequest req : requests) {
            LoanDetailsResult r = new LoanDetailsResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer Id is required.';
                    results.add(r);
                    continue;
                }

                List<FinServ__FinancialAccount__c> loans = [
                    SELECT Id, Name, FinServ__FinancialAccountType__c,
                           FinServ__PrincipalBalance__c, Current_EMI__c,
                           FinServ__LoanTermMonths__c, FinServ__InterestRate__c,
                           FinServ__OpenDate__c, FinServ__LoanEndDate__c,
                           Is_Restructured__c, Last_Restructure_Date__c
                    FROM FinServ__FinancialAccount__c
                    WHERE FinServ__PrimaryOwner__c = :req.customerId
                      AND FinServ__FinancialAccountType__c IN :LOAN_TYPES
                      AND FinServ__Status__c = 'Active'
                    ORDER BY FinServ__PrincipalBalance__c DESC
                ];

                if (loans.isEmpty()) {
                    r.success = false;
                    r.message = 'No loan accounts found for this customer.';
                    r.loanCount = 0;
                } else {
                    r.success = true;
                    r.loanCount = loans.size();
                    r.loanAccountId = loans[0].Id;
                    r.loanSummary = formatLoanDetails(loans);
                    r.message = 'Loan details retrieved successfully.';
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraLoanDetailsService', 'getLoanDetails', e);
                r.success = false;
                r.message = 'Error retrieving loan details: ' + e.getMessage();
                r.loanCount = 0;
            }
            results.add(r);
        }
        return results;
    }

    private static String formatLoanDetails(List<FinServ__FinancialAccount__c> loans) {
        Map<String, String> typeEmojis = new Map<String, String>{
            'Loan Account'  => '🏦',
            'Auto Loan'     => '🚗',
            'Mortgage'      => '🏠'
        };
        Map<String, String> optionLabels = new Map<String, String>{
            'A' => 'Extend tenure by 1 year',
            'B' => 'Extend tenure by 2 years',
            'C' => '3-month moratorium'
        };

        // Fetch last restructuring request for each loan (source of truth)
        Set<Id> loanIds = new Set<Id>();
        for (FinServ__FinancialAccount__c l : loans) { loanIds.add(l.Id); }
        Map<Id, Loan_Restructuring_Request__c> lastRequests = new Map<Id, Loan_Restructuring_Request__c>();
        for (Loan_Restructuring_Request__c req : [
            SELECT Id, Name, Loan_Financial_Account__c, CreatedDate, Selected_Option__c,
                   New_EMI__c, New_Tenure_Months__c, Original_EMI__c, Status__c
            FROM Loan_Restructuring_Request__c
            WHERE Loan_Financial_Account__c IN :loanIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!lastRequests.containsKey(req.Loan_Financial_Account__c)) {
                lastRequests.put(req.Loan_Financial_Account__c, req);
            }
        }

        String output = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Your Loan Details\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

        for (Integer i = 0; i < loans.size(); i++) {
            FinServ__FinancialAccount__c loan = loans[i];
            String loanType = loan.FinServ__FinancialAccountType__c;
            String emoji = typeEmojis.containsKey(loanType) ? typeEmojis.get(loanType) : '📋';

            output += emoji + ' ' + loanType + '\n';
            output += '   Account:    ' + loan.Name + '\n';
            output += '   Principal:  ₹' + formatCurrency(loan.FinServ__PrincipalBalance__c) + '\n';
            output += '   EMI:        ₹' + formatCurrency(loan.Current_EMI__c) + '/month\n';
            output += '   Rate:       ' + loan.FinServ__InterestRate__c + '% p.a.\n';
            output += '   Tenure:     ' + (loan.FinServ__LoanTermMonths__c != null ? Integer.valueOf(loan.FinServ__LoanTermMonths__c) : 0) + ' months remaining\n';
            output += '   Maturity:   ' + (loan.FinServ__LoanEndDate__c != null ? loan.FinServ__LoanEndDate__c.format() : 'N/A') + '\n';

            // Show last restructuring details if exists
            if (lastRequests.containsKey(loan.Id)) {
                Loan_Restructuring_Request__c lastReq = lastRequests.get(loan.Id);
                Date reqDate = lastReq.CreatedDate.date();
                String optLabel = optionLabels.containsKey(lastReq.Selected_Option__c)
                    ? lastReq.Selected_Option__c + ' — ' + optionLabels.get(lastReq.Selected_Option__c)
                    : lastReq.Selected_Option__c;

                output += '\n   📄 Last Restructuring:\n';
                output += '      Request #:  ' + lastReq.Name + '\n';
                output += '      Date:       ' + reqDate.format() + '\n';
                output += '      Option:     ' + optLabel + '\n';
                output += '      New EMI:    ₹' + formatCurrency(lastReq.New_EMI__c) + '/month\n';
                output += '      Status:     ' + lastReq.Status__c + '\n';

                // 90-day cooldown warning
                Date eligibleDate = reqDate.addDays(90);
                if (eligibleDate > Date.today()) {
                    output += '\n   ⚠️ IMPORTANT: You have already restructured this loan on ' + reqDate.format() + '.\n';
                    output += '   As per policy, a new restructuring request can only be submitted after ' + eligibleDate.format() + '.\n';
                    output += '   Please reach out after that date and we will be happy to assist you! 🙏\n';
                }
            }

            if (i < loans.size() - 1) {
                output += '──────────────────────────\n';
            }
        }

        output += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += '✅ ' + loans.size() + ' loan account(s) found\n';

        return output;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }

    public class LoanDetailsRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;
    }

    public class LoanDetailsResult {
        @InvocableVariable(label='Success' description='Whether loan details were retrieved successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message')
        public String message;

        @InvocableVariable(label='Loan Summary' description='Formatted loan details string')
        public String loanSummary;

        @InvocableVariable(label='Loan Account Id' description='Id of the FinServ__FinancialAccount__c loan record (for restructuring)')
        public Id loanAccountId;

        @InvocableVariable(label='Loan Count' description='Number of loan accounts found')
        public Integer loanCount;
    }
}