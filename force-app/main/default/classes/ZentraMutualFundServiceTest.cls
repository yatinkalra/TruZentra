@IsTest
private class ZentraMutualFundServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'MF Test Customer');
        insert acct;

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 100000,
            FinServ__Status__c = 'Active'
        );
        insert savings;

        FinServ__FinancialAccount__c investAcct = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Investment Account',
            FinServ__Status__c = 'Open'
        );
        insert investAcct;

        List<FinServ__FinancialHolding__c> sips = new List<FinServ__FinancialHolding__c>();
        sips.add(new FinServ__FinancialHolding__c(
            Fund_Name__c = 'HDFC Flexi Cap Fund',
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccount__c = investAcct.Id,
            Source_Account__c = savings.Id,
            SIP_Amount__c = 5000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-12),
            Total_Invested__c = 60000,
            FinServ__MarketValue__c = 72000,
            FinServ__Shares__c = 450.50,
            Installments_Completed__c = 12,
            SIP_Day__c = 5,
            Next_Installment_Date__c = Date.today().addDays(10)
        ));
        sips.add(new FinServ__FinancialHolding__c(
            Fund_Name__c = 'ICICI Bluechip Fund',
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccount__c = investAcct.Id,
            Source_Account__c = savings.Id,
            SIP_Amount__c = 3000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-6),
            Total_Invested__c = 18000,
            FinServ__MarketValue__c = 19500,
            FinServ__Shares__c = 200.25,
            Installments_Completed__c = 6,
            SIP_Day__c = 10
        ));
        sips.add(new FinServ__FinancialHolding__c(
            Fund_Name__c = 'Paused Fund',
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccount__c = investAcct.Id,
            Source_Account__c = savings.Id,
            SIP_Amount__c = 2000,
            Frequency__c = 'Monthly',
            Status__c = 'Paused',
            Start_Date__c = Date.today().addMonths(-3),
            Total_Invested__c = 6000,
            FinServ__MarketValue__c = 5800
        ));
        insert sips;
    }

    @IsTest
    static void testGetHoldings_Summary() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'MF Test Customer' LIMIT 1];

        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = String.valueOf(acct.Id);

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].outputMessage.contains('HDFC Flexi Cap'));
    }

    @IsTest
    static void testGetHoldings_Detail() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'MF Test Customer' LIMIT 1];

        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = String.valueOf(acct.Id);
        req.sipIndex = 1;

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testGetHoldings_InvalidIndex() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'MF Test Customer' LIMIT 1];

        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = String.valueOf(acct.Id);
        req.sipIndex = 99;

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].outputMessage.contains('Invalid selection'));
    }

    @IsTest
    static void testGetHoldings_IncludeInactive() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'MF Test Customer' LIMIT 1];

        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = String.valueOf(acct.Id);
        req.includeInactive = true;

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].outputMessage.contains('Paused Fund'));
    }

    @IsTest
    static void testGetHoldings_NoCustomerId() {
        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testGetHoldings_NoSIPs() {
        Account emptyAcct = new Account(Name = 'Empty MF Customer');
        insert emptyAcct;

        ZentraMutualFundService.MFRequest req = new ZentraMutualFundService.MFRequest();
        req.customerId = String.valueOf(emptyAcct.Id);

        Test.startTest();
        List<ZentraMutualFundService.MFResult> results =
            ZentraMutualFundService.getMutualFundHoldings(new List<ZentraMutualFundService.MFRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].outputMessage.contains('No mutual fund'));
    }
}
