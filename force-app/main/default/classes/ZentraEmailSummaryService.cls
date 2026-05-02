/**
 * ZentraEmailSummaryService
 * @description Invocable Apex service to send fresh summary emails to the customer.
 *              Queries latest live data and sends branded emails for:
 *              - Balance summary (all active financial accounts)
 *              - Dispute summary (latest dispute case)
 *              - Loan restructuring summary (latest restructuring request)
 *              Every invocation is a NEW email — not a resend.
 *              Customer must be OTP-verified before calling this service.
 * @developer   BlueForce Team
 * @date        2026-04-18
 */
public without sharing class ZentraEmailSummaryService {

    private static final Set<String> VALID_TYPES = new Set<String>{ 'balance', 'dispute', 'loan', 'transaction', 'recurring', 'mutualfund' };

    public class EmailSummaryRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='Email Type' description='Type of summary email: balance, dispute, loan, transaction, recurring, or mutualfund' required=true)
        public String emailType;
    }

    public class EmailSummaryResult {
        @InvocableVariable(label='Success' description='Whether the email was sent successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-facing status message')
        public String message;
    }

    @InvocableMethod(label='Send Email Summary'
        description='Sends a fresh summary email to the customer. Queries latest live data and emails: balance summary, dispute summary, or loan restructuring summary.'
        category='Email Services')
    public static List<EmailSummaryResult> sendEmailSummary(List<EmailSummaryRequest> requests) {
        List<EmailSummaryResult> results = new List<EmailSummaryResult>();

        for (EmailSummaryRequest req : requests) {
            EmailSummaryResult r = new EmailSummaryResult();
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
                    r.message = 'Invalid email type "' + req.emailType + '". Please choose: balance, dispute, loan, transaction, recurring, or mutualfund.';
                    results.add(r);
                    continue;
                }

                if (emailType == 'balance') {
                    r = sendBalanceSummary(req.customerId);
                } else if (emailType == 'dispute') {
                    r = sendDisputeSummary(req.customerId);
                } else if (emailType == 'loan') {
                    r = sendLoanSummary(req.customerId);
                } else if (emailType == 'transaction') {
                    r = sendTransactionSummary(req.customerId);
                } else if (emailType == 'recurring') {
                    r = sendRecurringPaymentSummary(req.customerId);
                } else if (emailType == 'mutualfund') {
                    r = sendMutualFundSummary(req.customerId);
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraEmailSummaryService', 'sendEmailSummary', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Something went wrong while sending the email. Please try again.';
            }
            results.add(r);
        }
        return results;
    }

    // ─── Balance summary email (fresh query) ───
    private static EmailSummaryResult sendBalanceSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

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
            r.message = 'Your account balance summary has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the balance summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Dispute summary email (latest dispute, fresh query) ───
    private static EmailSummaryResult sendDisputeSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraEmailSummaryService', 'sendDisputeSummary', e);
            r.success = false;
            r.message = 'Dispute record type not configured. Please contact support.';
            return r;
        }

        List<Case> disputes = [
            SELECT CaseNumber, Dispute_Amount__c, Dispute_Stage__c, Subject,
                   Provisional_Credit_Issued__c, Provisional_Credit_Amount__c,
                   Estimated_Resolution_Date__c, CreatedDate
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
        String merchantName = d.Subject != null ? d.Subject.replaceFirst('(?i)dispute\\s*[-\u2013\u2014:]?\\s*', '') : null;
        String estResolution = d.Estimated_Resolution_Date__c != null
            ? d.Estimated_Resolution_Date__c.format()
            : Date.today().addDays(7).format();

        Boolean sent = ZentraEmailService.sendDisputeSummaryEmail(
            customerId,
            d.CaseNumber,
            d.Dispute_Stage__c,
            d.Dispute_Amount__c,
            merchantName,
            estResolution,
            d.Provisional_Credit_Issued__c,
            d.Provisional_Credit_Amount__c,
            d.CreatedDate
        );

        if (sent) {
            r.success = true;
            r.message = 'Dispute summary for Case #' + d.CaseNumber
                + ' has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the dispute summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Loan restructuring summary email (latest request, fresh query) ───
    private static EmailSummaryResult sendLoanSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

        List<Loan_Restructuring_Request__c> reqs = [
            SELECT Name, Status__c, Selected_Option__c, Original_EMI__c, New_EMI__c,
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
            'A' => 'Option A \u2014 Extend 1 Year (+12 months)',
            'B' => 'Option B \u2014 Extend 2 Years (+24 months)',
            'C' => 'Option C \u2014 3-Month Moratorium'
        };
        String optLabel = optionLabels.containsKey(lr.Selected_Option__c)
            ? optionLabels.get(lr.Selected_Option__c)
            : lr.Selected_Option__c;

        String loanType = lr.Loan_Financial_Account__r != null
            ? lr.Loan_Financial_Account__r.FinServ__FinancialAccountType__c
            : 'Loan Account';

        Integer newTenure = lr.New_Tenure_Months__c != null ? Integer.valueOf(lr.New_Tenure_Months__c) : 0;

        Boolean sent = ZentraEmailService.sendLoanRestructuringSummaryEmail(
            customerId,
            lr.Name,
            lr.Status__c,
            loanType,
            optLabel,
            lr.Original_EMI__c != null ? lr.Original_EMI__c : 0,
            lr.New_EMI__c != null ? lr.New_EMI__c : 0,
            newTenure,
            lr.Monthly_Savings__c != null ? lr.Monthly_Savings__c : 0
        );

        if (sent) {
            r.success = true;
            r.message = 'Loan restructuring summary for Request #' + lr.Name
                + ' has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the loan restructuring summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Recurring payment summary email (all active standing instructions, fresh query) ───
    private static EmailSummaryResult sendRecurringPaymentSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

        List<Zentra_Recurring_Payment__c> check = [
            SELECT Id FROM Zentra_Recurring_Payment__c
            WHERE Customer__c = :customerId
              AND Status__c = 'Active'
            LIMIT 1
        ];

        if (check.isEmpty()) {
            r.success = false;
            r.message = 'No active recurring payments (standing instructions) found on your account. There is nothing to email.';
            return r;
        }

        Boolean sent = ZentraEmailService.sendRecurringPaymentSummaryEmail(customerId);
        if (sent) {
            r.success = true;
            r.message = 'Your recurring payments summary has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the recurring payments summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Transaction summary email (last 20 transactions, fresh query) ───
    private static EmailSummaryResult sendTransactionSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

        List<FinServ__FinancialAccountTransaction__c> check = [
            SELECT Id FROM FinServ__FinancialAccountTransaction__c
            WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :customerId
              AND FinServ__FinancialAccount__r.FinServ__Status__c = 'Active'
            LIMIT 1
        ];

        if (check.isEmpty()) {
            r.success = false;
            r.message = 'No recent transactions found on your account. There is nothing to email.';
            return r;
        }

        Boolean sent = ZentraEmailService.sendTransactionSummaryEmail(customerId);
        if (sent) {
            r.success = true;
            r.message = 'Your transaction summary has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the transaction summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }

    // ─── Mutual fund summary email (all active SIPs, fresh query) ───
    private static EmailSummaryResult sendMutualFundSummary(String customerId) {
        EmailSummaryResult r = new EmailSummaryResult();

        List<FinServ__FinancialHolding__c> check = [
            SELECT Id FROM FinServ__FinancialHolding__c
            WHERE FinServ__PrimaryOwner__c = :customerId
              AND Status__c = 'Active'
            LIMIT 1
        ];

        if (check.isEmpty()) {
            r.success = false;
            r.message = 'No active SIP / mutual fund holdings found on your account. There is nothing to email.';
            return r;
        }

        Boolean sent = ZentraEmailService.sendMutualFundSummaryEmail(customerId);
        if (sent) {
            r.success = true;
            r.message = 'Your mutual fund / SIP portfolio summary has been emailed to your registered email address. Please check your inbox.';
        } else {
            r.success = false;
            r.message = 'Unable to send the mutual fund summary email. Please ensure your account has a valid email address on file.';
        }
        return r;
    }
}