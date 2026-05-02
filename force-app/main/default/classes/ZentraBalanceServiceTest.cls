@IsTest
private class ZentraBalanceServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Balance Test Customer');
        insert acct;

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        FinServ__FinancialAccount__c credit = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Credit Card',
            FinServ__Balance__c = 15000,
            FinServ__TotalCreditLimit__c = 200000,
            FinServ__AvailableCredit__c = 185000,
            FinServ__Status__c = 'Active'
        );
        FinServ__FinancialAccount__c loan = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Loan Account',
            FinServ__PrincipalBalance__c = 500000,
            FinServ__InterestRate__c = 10.5,
            FinServ__LoanTermMonths__c = 36,
            Current_EMI__c = 16200,
            FinServ__Status__c = 'Active'
        );
        insert new List<FinServ__FinancialAccount__c>{ savings, credit, loan };
    }

    @IsTest
    static void testGetBalance_English() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Balance Test Customer' LIMIT 1];

        ZentraBalanceService.BalanceRequest req = new ZentraBalanceService.BalanceRequest();
        req.customerId = acct.Id;
        req.language = 'en';

        Test.startTest();
        List<ZentraBalanceService.BalanceResult> results =
            ZentraBalanceService.getBalance(new List<ZentraBalanceService.BalanceRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertEquals(3, results[0].accountCount);
        System.assert(results[0].balanceSummary.contains('Account Overview'));
    }

    @IsTest
    static void testGetBalance_Hindi() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Balance Test Customer' LIMIT 1];

        ZentraBalanceService.BalanceRequest req = new ZentraBalanceService.BalanceRequest();
        req.customerId = acct.Id;
        req.language = 'hi';

        Test.startTest();
        List<ZentraBalanceService.BalanceResult> results =
            ZentraBalanceService.getBalance(new List<ZentraBalanceService.BalanceRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(3, results[0].accountCount);
    }

    @IsTest
    static void testGetBalance_NoAccounts() {
        Account noAcct = new Account(Name = 'Empty Customer');
        insert noAcct;

        ZentraBalanceService.BalanceRequest req = new ZentraBalanceService.BalanceRequest();
        req.customerId = noAcct.Id;
        req.language = 'en';

        Test.startTest();
        List<ZentraBalanceService.BalanceResult> results =
            ZentraBalanceService.getBalance(new List<ZentraBalanceService.BalanceRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(0, results[0].accountCount);
    }
}
