/**
 * ZentraTransactionService - Returns recent financial account transactions for an authenticated customer.
 * Queries FinServ__FinancialAccountTransaction__c with configurable limit.
 * @author  BlueForce Team
 * @date    2026-04-10
 */
public without sharing class ZentraTransactionService {

    private static final Integer DEFAULT_LIMIT = 10;

    @InvocableMethod(label='Get Mini Statement'
        description='Returns the last N financial account transactions for an authenticated customer. Defaults to last 10 transactions.')
    public static List<TransactionResult> getTransactions(List<TransactionRequest> requests) {
        List<TransactionResult> results = new List<TransactionResult>();
        for (TransactionRequest req : requests) {
            TransactionResult r = new TransactionResult();
            try {
                Integer txnLimit = (req.transactionLimit != null && req.transactionLimit > 0)
                    ? Math.min(req.transactionLimit, 50)
                    : DEFAULT_LIMIT;

                List<FinServ__FinancialAccountTransaction__c> txns = [
                    SELECT Id,
                           Name,
                           FinServ__TransactionDate__c,
                           FinServ__Amount__c,
                           FinServ__Description__c,
                           FinServ__TransactionType__c,
                           FinServ__FinancialAccount__r.Name,
                           FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c
                    FROM FinServ__FinancialAccountTransaction__c
                    WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :req.customerId
                      AND FinServ__FinancialAccount__r.FinServ__Status__c = 'Active'
                    ORDER BY FinServ__TransactionDate__c DESC
                    LIMIT :txnLimit
                ];

                if (txns.isEmpty()) {
                    r.success = false;
                    r.transactionSummary = (req.language == 'hi')
                        ? 'कोई हाल का लेन-देन नहीं मिला।'
                        : 'No recent transactions found.';
                    r.transactionCount = 0;
                    r.transactionIds = '';
                } else {
                    r.success = true;
                    r.transactionSummary = formatTransactions(txns, req.language);
                    r.transactionCount = txns.size();
                    List<String> ids = new List<String>();
                    for (FinServ__FinancialAccountTransaction__c t : txns) {
                        ids.add(t.Id);
                    }
                    r.transactionIds = String.join(ids, ',');
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraTransactionService', 'getTransactions', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.transactionSummary = 'Error retrieving transactions: ' + e.getMessage();
                r.transactionCount = 0;
                r.transactionIds = '';
            }
            results.add(r);
        }
        return results;
    }

    private static String formatTransactions(List<FinServ__FinancialAccountTransaction__c> txns, String lang) {
        Boolean isHindi = (lang == 'hi');
        String output = isHindi
            ? '📋 आपके हाल के लेन-देन:\n\n'
            : '📋 Your Recent Transactions:\n\n';

        Integer idx = 1;
        for (FinServ__FinancialAccountTransaction__c t : txns) {
            String merchant = (t.FinServ__Description__c != null) ? t.FinServ__Description__c : 'Unknown';
            String dateStr = (t.FinServ__TransactionDate__c != null)
                ? t.FinServ__TransactionDate__c.format()
                : '';

            Decimal amt = (t.FinServ__Amount__c != null) ? t.FinServ__Amount__c : 0;
            String amtStr = '₹' + amt.format();

            String txnType = (t.FinServ__TransactionType__c != null) ? t.FinServ__TransactionType__c : '';
            String sign = txnType.equalsIgnoreCase('Credit') ? '+' : '-';

            output += idx + '. ' + merchant + '\n';
            output += '   ' + dateStr + '  |  ' + sign + amtStr + '\n';
            output += '   ID: ' + t.Id + '\n\n';
            idx++;
        }
        return output;
    }

    public class TransactionRequest {
        @InvocableVariable(required=true description='The Account Id of the authenticated customer.')
        public Id customerId;

        @InvocableVariable(description='Number of transactions to retrieve. Defaults to 10, max 50.')
        public Integer transactionLimit;

        @InvocableVariable(description='Language code: hi for Hindi, en for English. Defaults to en.')
        public String language;
    }

    public class TransactionResult {
        @InvocableVariable(description='Whether the transaction query was successful.')
        public Boolean success;

        @InvocableVariable(description='Formatted transaction list string ready for display to the customer.')
        public String transactionSummary;

        @InvocableVariable(description='Number of transactions returned.')
        public Integer transactionCount;

        @InvocableVariable(description='Comma-separated list of transaction record Ids for selection.')
        public String transactionIds;
    }
}