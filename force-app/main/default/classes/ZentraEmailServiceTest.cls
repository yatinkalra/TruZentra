@IsTest
private class ZentraEmailServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Email Test Customer');
        insert acct;

        Contact con = new Contact(
            LastName = 'EmailTest', FirstName = 'Test',
            Email = 'email.test@example.com', AccountId = acct.Id
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
            FinServ__Balance__c = 15000,
            FinServ__TotalCreditLimit__c = 200000,
            FinServ__AvailableCredit__c = 185000,
            FinServ__Status__c = 'Active'
        );
        insert new List<FinServ__FinancialAccount__c>{ savings, credit };

        FinServ__FinancialAccountTransaction__c txn = new FinServ__FinancialAccountTransaction__c(
            FinServ__FinancialAccount__c = savings.Id,
            FinServ__Amount__c = 500,
            FinServ__TransactionDate__c = Date.today(),
            FinServ__Description__c = 'Test Txn',
            FinServ__TransactionType__c = 'Debit'
        );
        insert txn;

        Zentra_Recurring_Payment__c rp = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = savings.Id,
            Payee_Name__c = 'Electricity Board',
            Amount__c = 1500,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-6),
            Next_Payment_Date__c = Date.today().addDays(10)
        );
        insert rp;

        FinServ__FinancialAccount__c investAcct = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Investment Account',
            FinServ__Status__c = 'Open'
        );
        insert investAcct;

        FinServ__FinancialHolding__c sip = new FinServ__FinancialHolding__c(
            Fund_Name__c = 'HDFC Flexi Cap',
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccount__c = investAcct.Id,
            Source_Account__c = savings.Id,
            SIP_Amount__c = 5000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-6),
            Total_Invested__c = 30000,
            FinServ__MarketValue__c = 35000
        );
        insert sip;
    }

    private static void injectMockConfig() {
        ZentraEmailService.configCache = new Map<String, Zentra_Email_Config__mdt>();
        Zentra_Email_Config__mdt master = new Zentra_Email_Config__mdt(
            DeveloperName = 'Master',
            Is_Enabled__c = true,
            Brand_Color__c = '#1a237e',
            Accent_Color__c = '#4caf50',
            Bank_Name__c = 'Test Bank'
        );
        ZentraEmailService.configCache.put('Master', master);
    }

    @IsTest
    static void testSendBalanceSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendBalanceSummaryEmail(acct.Id);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendBalanceSummaryEmail_NoAccounts() {
        injectMockConfig();
        Account emptyAcct = new Account(Name = 'No FA Acct');
        insert emptyAcct;
        Contact c = new Contact(LastName = 'X', Email = 'x@test.com', AccountId = emptyAcct.Id);
        insert c;

        Test.startTest();
        Boolean sent = ZentraEmailService.sendBalanceSummaryEmail(emptyAcct.Id);
        Test.stopTest();

        System.assertEquals(false, sent);
    }

    @IsTest
    static void testSendDisputeConfirmationEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendDisputeConfirmationEmail(
            acct.Id, '00001234', 2999, 'Amazon', Date.today().addDays(7).format());
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendLoanRestructuringEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendLoanRestructuringEmail(
            acct.Id, 'REQ-001', 'Loan Account', 'Option A', 16200, 14500, 48, 1700);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendTransactionSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendTransactionSummaryEmail(acct.Id);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendDisputeSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendDisputeSummaryEmail(
            acct.Id, '00001234', 'Filed', 2999, 'Amazon',
            Date.today().addDays(7).format(), true, 2999, DateTime.now());
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendLoanRestructuringSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendLoanRestructuringSummaryEmail(
            acct.Id, 'REQ-002', 'Submitted', 'Loan Account', 'Option B', 16200, 13000, 60, 3200);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendRecurringPaymentSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendRecurringPaymentSummaryEmail(acct.Id);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSendMutualFundSummaryEmail() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Email Test Customer' LIMIT 1];

        Test.startTest();
        Boolean sent = ZentraEmailService.sendMutualFundSummaryEmail(acct.Id);
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testIsEnabled_Disabled() {
        ZentraEmailService.configCache = new Map<String, Zentra_Email_Config__mdt>();
        Zentra_Email_Config__mdt master = new Zentra_Email_Config__mdt(
            DeveloperName = 'Master',
            Is_Enabled__c = false
        );
        ZentraEmailService.configCache.put('Master', master);

        Test.startTest();
        Boolean enabled = ZentraEmailService.isEnabled('Balance_Summary');
        Test.stopTest();

        System.assertEquals(false, enabled);
    }

    @IsTest
    static void testSendEmail_NoContact() {
        injectMockConfig();
        Account noContact = new Account(Name = 'No Contact Acct');
        insert noContact;

        Test.startTest();
        Boolean sent = ZentraEmailService.sendBalanceSummaryEmail(noContact.Id);
        Test.stopTest();

        System.assertEquals(false, sent);
    }
}
