@IsTest
private class ZentraTransactionServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Transaction Test Customer');
        insert acct;

        FinServ__FinancialAccount__c fa = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        insert fa;

        List<FinServ__FinancialAccountTransaction__c> txns = new List<FinServ__FinancialAccountTransaction__c>();
        for (Integer i = 0; i < 15; i++) {
            txns.add(new FinServ__FinancialAccountTransaction__c(
                FinServ__FinancialAccount__c = fa.Id,
                FinServ__Amount__c = 100 + i * 50,
                FinServ__TransactionDate__c = Date.today().addDays(-i),
                FinServ__Description__c = 'Merchant ' + i,
                FinServ__TransactionType__c = Math.mod(i, 2) == 0 ? 'Debit' : 'Credit'
            ));
        }
        insert txns;
    }

    @IsTest
    static void testGetTransactions_DefaultLimit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Transaction Test Customer' LIMIT 1];

        ZentraTransactionService.TransactionRequest req = new ZentraTransactionService.TransactionRequest();
        req.customerId = acct.Id;
        req.language = 'en';

        Test.startTest();
        List<ZentraTransactionService.TransactionResult> results =
            ZentraTransactionService.getTransactions(new List<ZentraTransactionService.TransactionRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(10, results[0].transactionCount);
        System.assert(String.isNotBlank(results[0].transactionIds));
    }

    @IsTest
    static void testGetTransactions_CustomLimit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Transaction Test Customer' LIMIT 1];

        ZentraTransactionService.TransactionRequest req = new ZentraTransactionService.TransactionRequest();
        req.customerId = acct.Id;
        req.transactionLimit = 5;

        Test.startTest();
        List<ZentraTransactionService.TransactionResult> results =
            ZentraTransactionService.getTransactions(new List<ZentraTransactionService.TransactionRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(5, results[0].transactionCount);
    }

    @IsTest
    static void testGetTransactions_NoTransactions() {
        Account noAcct = new Account(Name = 'Empty Txn Customer');
        insert noAcct;

        ZentraTransactionService.TransactionRequest req = new ZentraTransactionService.TransactionRequest();
        req.customerId = noAcct.Id;

        Test.startTest();
        List<ZentraTransactionService.TransactionResult> results =
            ZentraTransactionService.getTransactions(new List<ZentraTransactionService.TransactionRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(0, results[0].transactionCount);
    }

    @IsTest
    static void testGetTransactions_Hindi() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Transaction Test Customer' LIMIT 1];

        ZentraTransactionService.TransactionRequest req = new ZentraTransactionService.TransactionRequest();
        req.customerId = acct.Id;
        req.language = 'hi';
        req.transactionLimit = 3;

        Test.startTest();
        List<ZentraTransactionService.TransactionResult> results =
            ZentraTransactionService.getTransactions(new List<ZentraTransactionService.TransactionRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }
}
