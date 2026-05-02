@IsTest
private class ZentraDisputeServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Dispute Test Customer');
        insert acct;

        Contact con = new Contact(
            LastName = 'DisputeTest', FirstName = 'Test',
            Email = 'dispute.test@example.com', AccountId = acct.Id
        );
        insert con;

        FinServ__FinancialAccount__c fa = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        insert fa;

        FinServ__FinancialAccountTransaction__c txn = new FinServ__FinancialAccountTransaction__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__Amount__c = 2999,
            FinServ__TransactionDate__c = Date.today().addDays(-2),
            FinServ__Description__c = 'Amazon India',
            FinServ__TransactionType__c = 'Debit'
        );
        insert txn;
    }

    private static Id getDisputeRT() {
        try {
            return Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            return null;
        }
    }

    @IsTest
    static void testCreateDispute_ByTransactionId() {
        if (getDisputeRT() == null) return; // skip if RT not available

        Account acct = [SELECT Id FROM Account WHERE Name = 'Dispute Test Customer' LIMIT 1];
        FinServ__FinancialAccountTransaction__c txn = [
            SELECT Id FROM FinServ__FinancialAccountTransaction__c
            WHERE FinServ__Description__c = 'Amazon India' LIMIT 1
        ];

        ZentraDisputeService.DisputeRequest req = new ZentraDisputeService.DisputeRequest();
        req.customerId = acct.Id;
        req.transactionId = txn.Id;
        req.reason = 'Suspected Fraud';

        Test.startTest();
        List<ZentraDisputeService.DisputeResult> results =
            ZentraDisputeService.createDispute(new List<ZentraDisputeService.DisputeRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertNotEquals(null, results[0].caseNumber);
        System.assertEquals(2999, results[0].disputeAmount);
        System.assertEquals(true, results[0].provisionalCreditIssued);
    }

    @IsTest
    static void testCreateDispute_ByAmountAndMerchant() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'Dispute Test Customer' LIMIT 1];

        ZentraDisputeService.DisputeRequest req = new ZentraDisputeService.DisputeRequest();
        req.customerId = acct.Id;
        req.amount = 2999;
        req.merchantHint = 'Amazon';
        req.reason = 'Transaction not recognized';

        Test.startTest();
        List<ZentraDisputeService.DisputeResult> results =
            ZentraDisputeService.createDispute(new List<ZentraDisputeService.DisputeRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testCreateDispute_NoMatchByAmount() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'Dispute Test Customer' LIMIT 1];

        ZentraDisputeService.DisputeRequest req = new ZentraDisputeService.DisputeRequest();
        req.customerId = acct.Id;
        req.amount = 99999;

        Test.startTest();
        List<ZentraDisputeService.DisputeResult> results =
            ZentraDisputeService.createDispute(new List<ZentraDisputeService.DisputeRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testCreateDispute_MissingInputs() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'Dispute Test Customer' LIMIT 1];

        ZentraDisputeService.DisputeRequest req = new ZentraDisputeService.DisputeRequest();
        req.customerId = acct.Id;
        // no transactionId or amount

        Test.startTest();
        List<ZentraDisputeService.DisputeResult> results =
            ZentraDisputeService.createDispute(new List<ZentraDisputeService.DisputeRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('provide either'));
    }
}
