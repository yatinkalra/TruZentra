@IsTest
private class ZentraRMDashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Dashboard Test Customer', Phone = '9876543210');
        insert acct;

        Contact con = new Contact(
            LastName = 'DashTest', FirstName = 'Test',
            Email = 'dash@test.com', AccountId = acct.Id
        );
        insert con;

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        FinServ__FinancialAccount__c credit = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Credit Card',
            FinServ__Balance__c = 5000,
            FinServ__Status__c = 'Active'
        );
        insert new List<FinServ__FinancialAccount__c>{ savings, credit };

        FinServ__FinancialAccountTransaction__c txn = new FinServ__FinancialAccountTransaction__c(
            FinServ__FinancialAccount__c = savings.Id,
            FinServ__Amount__c = 1000,
            FinServ__TransactionDate__c = Date.today(),
            FinServ__Description__c = 'Test Txn'
        );
        insert txn;

        Zentra_Recurring_Payment__c rp = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = savings.Id,
            Payee_Name__c = 'Utility',
            Amount__c = 1000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today()
        );
        insert rp;

        FinServ__FinancialAccount__c investAcct = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Investment Account',
            FinServ__Status__c = 'Open'
        );
        insert investAcct;

        FinServ__FinancialHolding__c sip = new FinServ__FinancialHolding__c(
            Fund_Name__c = 'Test Fund',
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccount__c = investAcct.Id,
            Source_Account__c = savings.Id,
            SIP_Amount__c = 5000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today()
        );
        insert sip;
    }

    @IsTest
    static void testSearchAccounts() {
        Test.startTest();
        List<Account> results = ZentraRMDashboardController.searchAccounts('Dashboard Test');
        Test.stopTest();

        System.assert(!results.isEmpty());
    }

    @IsTest
    static void testSearchAccounts_ShortTerm() {
        Test.startTest();
        List<Account> results = ZentraRMDashboardController.searchAccounts('D');
        Test.stopTest();

        System.assert(results.isEmpty());
    }

    @IsTest
    static void testGetDashboardData() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Dashboard Test Customer' LIMIT 1];

        Test.startTest();
        ZentraRMDashboardController.DashboardData data =
            ZentraRMDashboardController.getDashboardData(acct.Id);
        Test.stopTest();

        System.assertNotEquals(null, data.account);
        System.assertNotEquals(null, data.primaryContact);
        System.assert(!data.financialAccounts.isEmpty());
        System.assert(!data.recentTransactions.isEmpty());
        System.assert(!data.recurringPayments.isEmpty());
        System.assert(!data.sipRecords.isEmpty());
    }

    @IsTest
    static void testFreezeAndReactivateAccount() {
        FinServ__FinancialAccount__c fa = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__FinancialAccountType__c = 'Savings Account' LIMIT 1
        ];

        Test.startTest();
        ZentraRMDashboardController.freezeFinancialAccount(fa.Id);
        Test.stopTest();

        FinServ__FinancialAccount__c frozen = [SELECT FinServ__Status__c FROM FinServ__FinancialAccount__c WHERE Id = :fa.Id];
        System.assertEquals('Inactive', frozen.FinServ__Status__c);

        ZentraRMDashboardController.reactivateFinancialAccount(fa.Id);
        FinServ__FinancialAccount__c reactivated = [SELECT FinServ__Status__c FROM FinServ__FinancialAccount__c WHERE Id = :fa.Id];
        System.assertEquals('Active', reactivated.FinServ__Status__c);
    }

    @IsTest
    static void testStopRecurringPayment() {
        Zentra_Recurring_Payment__c rp = [SELECT Id FROM Zentra_Recurring_Payment__c LIMIT 1];

        Test.startTest();
        ZentraRMDashboardController.stopRecurringPayment(rp.Id);
        Test.stopTest();

        Zentra_Recurring_Payment__c stopped = [SELECT Status__c FROM Zentra_Recurring_Payment__c WHERE Id = :rp.Id];
        System.assertEquals('Cancelled', stopped.Status__c);
    }

    @IsTest
    static void testDeactivateAllAccountsAndCards() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Dashboard Test Customer' LIMIT 1];

        Test.startTest();
        ZentraRMDashboardController.deactivateAllAccountsAndCards(acct.Id);
        Test.stopTest();

        List<FinServ__FinancialAccount__c> fas = [
            SELECT FinServ__Status__c FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c IN ('Savings Account', 'Credit Card')
        ];
        for (FinServ__FinancialAccount__c fa : fas) {
            System.assertEquals('Inactive', fa.FinServ__Status__c);
        }
    }

    @IsTest
    static void testReactivateAllAccountsAndCards() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Dashboard Test Customer' LIMIT 1];
        ZentraRMDashboardController.deactivateAllAccountsAndCards(acct.Id);

        Test.startTest();
        ZentraRMDashboardController.reactivateAllAccountsAndCards(acct.Id);
        Test.stopTest();

        List<FinServ__FinancialAccount__c> fas = [
            SELECT FinServ__Status__c FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c IN ('Savings Account', 'Credit Card')
        ];
        for (FinServ__FinancialAccount__c fa : fas) {
            System.assertEquals('Active', fa.FinServ__Status__c);
        }
    }

    @IsTest
    static void testFileTransactionDispute() {
        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            return;
        }

        Account acct = [SELECT Id FROM Account WHERE Name = 'Dashboard Test Customer' LIMIT 1];
        FinServ__FinancialAccountTransaction__c txn = [
            SELECT Id FROM FinServ__FinancialAccountTransaction__c LIMIT 1
        ];

        Test.startTest();
        Id caseId = ZentraRMDashboardController.fileTransactionDispute(
            txn.Id, acct.Id, 'Unauthorized Transaction', 'Test dispute');
        Test.stopTest();

        System.assertNotEquals(null, caseId);
        Case c = [SELECT Dispute_Amount__c, Dispute_Stage__c FROM Case WHERE Id = :caseId];
        System.assertEquals('Filed', c.Dispute_Stage__c);
    }
}
