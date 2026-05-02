/**
 * ZentraResendConfirmationService
 * @description Invocable Apex service to send fresh summary emails:
 *              - Balance summary (queries live account data)
 *              - Dispute summary (latest dispute case)
 *              - Loan restructuring summary (latest request)
 *              Treats every request as a NEW email send, not a resend.
 *              Customer must be OTP-verified before calling this service.
 * @developer   BlueForce Team
 * @date        2026-04-17
 */
public without sharing class ZentraResendConfirmationService {

    private static final Set<String> VALID_TYPES = new Set<String>{ 'balance', 'dispute', 'loan' };

    public class ResendRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='Email Type' description='Type of email to resend: balance, dispute, or loan' required=true)
        public String emailType;
    }

    public class ResendResult {
        @InvocableVariable(label='Success' description='Whether the email was resent successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-facing status message')
        public String message;
    }

    @InvocableMethod(label='Send Email Summary'
        description='Sends a fresh summary email to the customer. Queries latest data and sends: balance summary, dispute summary, or loan restructuring summary.'
        category='Email Services')
    public static List<ResendResult> resendConfirmation(List<ResendRequest> requests) {
        List<ResendResult> results = new List<ResendResult>();

        for (ResendRequest req : requests) {
            ResendResult r = new ResendResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer Id is required.';
                    results.add(r);
                    continue;
                }
                String emailType = String.isNotBlank(req.emailType) ? req.emailType.toLowerCase().trim() : '';
                if (!VALID_TYPES.contains(emailType)) {
                    r.success = false;
                    r.message = 'Invalid email type "' + req.emailType + '". Please choose: balance, dispute, or loan.';
                    results.add(r);
                    continue;
                }

                if (emailType == 'balance') {
                    r = sendBalanceSummary(req.customerId);
                } else if (emailType == 'dispute') {
                    r = sendDisputeSummary(req.customerId);
                } else if (emailType == 'loan') {
                    r = sendLoanSummary(req.customerId);
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraResendConfirmationService', 'resendConfirmation', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Something went wrong while sending the email. Please try again.';
            }
            results.add(r);
        }
        return results;
    }

    // ─── Balance summary email (fresh query) ───
    private static ResendResult sendBalanceSummary(String customerId) {
        ResendResult r = new ResendResult();

        List<FinServ__FinancialAccount__c> accounts = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :customerId
              AND FinServ__Status__c = 'Active'
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            r.success = false;
            r.message = 'No active financial accounts found for your profile. Please contact support.';
            return r;
        }

        Boolean sent = ZentraEmailService.sendBalanceSummaryEmail(customerId);
        if (sent) {
            r.success = true;
            r.message = '✅ Your account balance summary has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the balance summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Dispute summary email (latest dispute, fresh query) ───
    private static ResendResult sendDisputeSummary(String customerId) {
        ResendResult r = new ResendResult();

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraResendConfirmationService', 'sendDisputeSummary', e);
            r.success = false;
            r.message = 'Dispute record type not configured. Please contact support.';
            return r;
        }

        List<Case> disputes = [
            SELECT CaseNumber, Dispute_Amount__c, Subject,
                   Estimated_Resolution_Date__c
            FROM Case
            WHERE AccountId = :customerId
              AND RecordTypeId = :disputeRT
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (disputes.isEmpty()) {
            r.success = false;
            r.message = 'No dispute cases found on your account. There is nothing to email.';
            return r;
        }

        Case d = disputes[0];
        String merchantName = d.Subject != null ? d.Subject.replaceFirst('(?i)dispute\\s*[-–—:]?\\s*', '') : null;
        String estResolution = d.Estimated_Resolution_Date__c != null
            ? d.Estimated_Resolution_Date__c.format()
            : Date.today().addDays(7).format();

        Boolean sent = ZentraEmailService.sendDisputeConfirmationEmail(
            customerId,
            d.CaseNumber,
            d.Dispute_Amount__c,
            merchantName,
            estResolution
        );

        if (sent) {
            r.success = true;
            r.message = '✅ Dispute summary for Case #' + d.CaseNumber
                + ' has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the dispute summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Loan restructuring summary email (latest request, fresh query) ───
    private static ResendResult sendLoanSummary(String customerId) {
        ResendResult r = new ResendResult();

        List<Loan_Restructuring_Request__c> reqs = [
            SELECT Name, Selected_Option__c, Original_EMI__c, New_EMI__c,
                   New_Tenure_Months__c, Monthly_Savings__c,
                   Loan_Financial_Account__r.FinServ__FinancialAccountType__c
            FROM Loan_Restructuring_Request__c
            WHERE Customer__c = :customerId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (reqs.isEmpty()) {
            r.success = false;
            r.message = 'No loan restructuring requests found on your account. There is nothing to email.';
            return r;
        }

        Loan_Restructuring_Request__c lr = reqs[0];

        Map<String, String> optionLabels = new Map<String, String>{
            'A' => 'Option A — Extend 1 Year (+12 months)',
            'B' => 'Option B — Extend 2 Years (+24 months)',
            'C' => 'Option C — 3-Month Moratorium'
        };
        String optLabel = optionLabels.containsKey(lr.Selected_Option__c)
            ? optionLabels.get(lr.Selected_Option__c)
            : lr.Selected_Option__c;

        String loanType = lr.Loan_Financial_Account__r != null
            ? lr.Loan_Financial_Account__r.FinServ__FinancialAccountType__c
            : 'Loan Account';

        Integer newTenure = lr.New_Tenure_Months__c != null ? Integer.valueOf(lr.New_Tenure_Months__c) : 0;

        Boolean sent = ZentraEmailService.sendLoanRestructuringEmail(
            customerId,
            lr.Name,
            loanType,
            optLabel,
            lr.Original_EMI__c != null ? lr.Original_EMI__c : 0,
            lr.New_EMI__c != null ? lr.New_EMI__c : 0,
            newTenure,
            lr.Monthly_Savings__c != null ? lr.Monthly_Savings__c : 0
        );

        if (sent) {
            r.success = true;
            r.message = '✅ Loan restructuring summary for Request #' + lr.Name
                + ' has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the loan restructuring summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }
}