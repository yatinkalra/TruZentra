/**
 * ZentraDisputeService - Creates dispute cases against unauthorized/incorrect transactions.
 * Supports exact transaction ID or fuzzy matching by amount + merchant.
 * Issues provisional credit and creates Case with Dispute record type.
 * @author  BlueForce Team
 * @date    2026-04-15
 */
public without sharing class ZentraDisputeService {

    @InvocableMethod(label='Create Dispute Case'
        description='Creates a dispute case against a specific transaction. Marks the transaction as disputed and issues provisional credit.')
    public static List<DisputeResult> createDispute(List<DisputeRequest> requests) {
        List<DisputeResult> results = new List<DisputeResult>();

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraDisputeService', 'raiseDispute', e);
            DisputeResult errResult = new DisputeResult();
            errResult.success = false;
            errResult.message = 'Dispute record type not configured. Please contact support.';
            results.add(errResult);
            return results;
        }

        for (DisputeRequest req : requests) {
            DisputeResult r = new DisputeResult();

            try {
                FinServ__FinancialAccountTransaction__c txn;

                if (req.transactionId != null) {
                    List<FinServ__FinancialAccountTransaction__c> txns = [
                        SELECT Id, Name, FinServ__Amount__c,
                               FinServ__TransactionDate__c, FinServ__Description__c,
                               FinServ__FinancialAccount__c,
                               FinServ__FinancialAccount__r.Name,
                               FinServ__FinancialAccount__r.FinServ__FinancialAccountNumber__c,
                               FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c,
                               FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c,
                               FinServ__FinancialAccount__r.FinServ__PrimaryOwner__r.Name
                        FROM FinServ__FinancialAccountTransaction__c
                        WHERE Id = :req.transactionId
                          AND FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :req.customerId
                        LIMIT 1
                    ];
                    if (txns.isEmpty()) {
                        r.success = false;
                        r.message = 'Transaction not found or does not belong to your account.';
                        results.add(r);
                        continue;
                    }
                    txn = txns[0];
                } else if (req.amount != null) {
                    String merchantFilter = (req.merchantHint != null)
                        ? '%' + req.merchantHint + '%'
                        : '%';

                    List<FinServ__FinancialAccountTransaction__c> txns = [
                        SELECT Id, Name, FinServ__Amount__c,
                               FinServ__TransactionDate__c, FinServ__Description__c,
                               FinServ__FinancialAccount__c,
                               FinServ__FinancialAccount__r.Name,
                               FinServ__FinancialAccount__r.FinServ__FinancialAccountNumber__c,
                               FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c,
                               FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c,
                               FinServ__FinancialAccount__r.FinServ__PrimaryOwner__r.Name
                        FROM FinServ__FinancialAccountTransaction__c
                        WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :req.customerId
                          AND FinServ__Amount__c = :req.amount
                          AND FinServ__Description__c LIKE :merchantFilter
                        ORDER BY FinServ__TransactionDate__c DESC
                        LIMIT 1
                    ];
                    if (txns.isEmpty()) {
                        r.success = false;
                        r.message = 'Transaction not found matching the given amount and merchant. Please check details or select from your recent transactions.';
                        results.add(r);
                        continue;
                    }
                    txn = txns[0];
                } else {
                    r.success = false;
                    r.message = 'Please provide either a transaction ID or amount to file a dispute.';
                    results.add(r);
                    continue;
                }

                // Mark transaction as disputed with reason (picklist)
                txn.FinServ__IsDisputed__c = true;
                txn.FinServ__DisputeReason__c = mapDisputeReason(req.reason);
                update txn;

                String merchantDisplay = (txn.FinServ__Description__c != null) ? txn.FinServ__Description__c : 'Unknown Transaction';
                String acctName = txn.FinServ__FinancialAccount__r?.FinServ__PrimaryOwner__r?.Name;
                String faName = txn.FinServ__FinancialAccount__r?.Name;
                String faNumber = txn.FinServ__FinancialAccount__r?.FinServ__FinancialAccountNumber__c;
                String faType = txn.FinServ__FinancialAccount__r?.FinServ__FinancialAccountType__c;

                String fullDesc = 'Dispute Reason: ' + (String.isNotBlank(req.reason) ? req.reason : '—') + '\n'
                    + 'Source: Agentforce (WhatsApp)\n\n'
                    + '── Account Details ──\n'
                    + 'Account Name: ' + (acctName != null ? acctName : '—') + '\n'
                    + 'Financial Account: ' + (faName != null ? faName : '—') + '\n'
                    + 'Account Number: ' + (faNumber != null ? faNumber : '—') + '\n'
                    + 'Account Type: ' + (faType != null ? faType : '—') + '\n\n'
                    + '── Transaction Details ──\n'
                    + 'Transaction ID: ' + txn.Name + '\n'
                    + 'Merchant: ' + merchantDisplay + '\n'
                    + 'Amount: ₹' + txn.FinServ__Amount__c + '\n'
                    + 'Date: ' + (txn.FinServ__TransactionDate__c != null ? String.valueOf(txn.FinServ__TransactionDate__c) : '—') + '\n\n'
                    + '── Provisional Credit ──\n'
                    + 'Credit Amount: ₹' + txn.FinServ__Amount__c + '\n'
                    + 'Credit Issued: Yes (Automatic)';

                Case dispute = new Case(
                    RecordTypeId = disputeRT,
                    AccountId = req.customerId,
                    Disputed_Transaction__c = txn.Id,
                    Dispute_Amount__c = txn.FinServ__Amount__c,
                    Dispute_Stage__c = 'Filed',
                    Provisional_Credit_Issued__c = true,
                    Provisional_Credit_Amount__c = txn.FinServ__Amount__c,
                    Estimated_Resolution_Date__c = Date.today().addDays(7),
                    Subject = 'Dispute: ' + merchantDisplay + ' ₹' + txn.FinServ__Amount__c,
                    Description = fullDesc
                );
                insert dispute;

                String caseNumber = [SELECT CaseNumber FROM Case WHERE Id = :dispute.Id LIMIT 1].CaseNumber;

                r.success = true;
                r.caseId = dispute.Id;
                r.caseNumber = caseNumber;
                r.disputeAmount = txn.FinServ__Amount__c;
                r.provisionalCreditIssued = true;
                r.estimatedResolutionDate = Date.today().addDays(7).format();
                r.message = 'Dispute filed successfully. Case #' + caseNumber
                    + '. Provisional credit of ₹' + txn.FinServ__Amount__c
                    + ' has been issued. Estimated resolution by '
                    + Date.today().addDays(7).format() + '.'
                    + ' A confirmation email with all the details has been sent to your registered email address.';

                // Send confirmation email
                ZentraEmailService.sendDisputeConfirmationEmail(
                    req.customerId,
                    caseNumber,
                    txn.FinServ__Amount__c,
                    merchantDisplay,
                    Date.today().addDays(7).format()
                );
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraDisputeService', 'raiseDispute', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Error filing dispute: ' + e.getMessage();
            }

            results.add(r);
        }
        return results;
    }

    public class DisputeRequest {
        @InvocableVariable(required=true description='The Account Id of the authenticated customer.')
        public Id customerId;

        @InvocableVariable(description='The specific transaction record Id to dispute. Use this if the customer selected from a list.')
        public Id transactionId;

        @InvocableVariable(description='Transaction amount for fuzzy matching when transaction Id is not available.')
        public Decimal amount;

        @InvocableVariable(description='Merchant name hint for fuzzy matching.')
        public String merchantHint;

        @InvocableVariable(description='Reason for the dispute. Must be one of: Duplicate Transactions, Transaction not recognized, Suspected Fraud, Others.')
        public String reason;
    }

    private static final Set<String> VALID_REASONS = new Set<String>{
        'Duplicate Transactions', 'Transaction not recognized', 'Suspected Fraud', 'Others'
    };

    private static String mapDisputeReason(String reason) {
        if (String.isBlank(reason)) return 'Others';
        // Exact match first
        for (String valid : VALID_REASONS) {
            if (valid.equalsIgnoreCase(reason.trim())) return valid;
        }
        // Keyword matching
        String lower = reason.toLowerCase();
        if (lower.contains('duplicate')) return 'Duplicate Transactions';
        if (lower.contains('not recognized') || lower.contains('unrecognized') || lower.contains('unknown') || lower.contains('not recogni')) return 'Transaction not recognized';
        if (lower.contains('fraud') || lower.contains('unauthorized') || lower.contains('suspicious')) return 'Suspected Fraud';
        return 'Others';
    }

    public class DisputeResult {
        @InvocableVariable(description='Whether the dispute was filed successfully.')
        public Boolean success;

        @InvocableVariable(description='The Case record Id of the created dispute.')
        public Id caseId;

        @InvocableVariable(description='The Case Number for reference.')
        public String caseNumber;

        @InvocableVariable(description='The amount being disputed.')
        public Decimal disputeAmount;

        @InvocableVariable(description='Whether provisional credit was issued.')
        public Boolean provisionalCreditIssued;

        @InvocableVariable(description='Expected resolution date string.')
        public String estimatedResolutionDate;

        @InvocableVariable(description='Human-readable result message.')
        public String message;
    }
}