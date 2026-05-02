@IsTest
private class ZentraEmailSummaryServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'EmailSummary Test');
        insert acct;

        Contact con = new Contact(
            LastName = 'SummaryTest', FirstName = 'Test',
            Email = 'summary.test@example.com', AccountId = acct.Id
        );
        insert con;

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        insert savings;

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
            Payee_Name__c = 'Utility',
            Amount__c = 1000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-3),
            Next_Payment_Date__c = Date.today().addDays(5)
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
            SIP_Amount__c = 3000,
            Frequency__c = 'Monthly',
            Status__c = 'Active',
            Start_Date__c = Date.today().addMonths(-3),
            Total_Invested__c = 9000,
            FinServ__MarketValue__c = 10000
        );
        insert sip;

        FinServ__FinancialAccount__c loan = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Loan Account',
            FinServ__PrincipalBalance__c = 500000,
            FinServ__InterestRate__c = 10.5,
            FinServ__LoanTermMonths__c = 36,
            FinServ__LoanAmount__c = 800000,
            Current_EMI__c = 16200,
            FinServ__Status__c = 'Active'
        );
        insert loan;

        Id disputeRT = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        Case dispute = new Case(
            RecordTypeId = disputeRT,
            AccountId = acct.Id,
            Dispute_Amount__c = 2999,
            Dispute_Stage__c = 'Filed',
            Subject = 'Dispute: Amazon',
            Provisional_Credit_Issued__c = true,
            Provisional_Credit_Amount__c = 2999,
            Estimated_Resolution_Date__c = Date.today().addDays(7)
        );
        insert dispute;

        Loan_Restructuring_Request__c lrr = new Loan_Restructuring_Request__c(
            Customer__c = acct.Id,
            Loan_Financial_Account__c = loan.Id,
            Selected_Option__c = 'B',
            Original_EMI__c = 16200,
            New_EMI__c = 13000,
            New_Tenure_Months__c = 60,
            Additional_Interest__c = 30000,
            Status__c = 'Submitted'
        );
        insert lrr;
    }

    private static void injectMockConfig() {
        ZentraEmailService.configCache = new Map<String, Zentra_Email_Config__mdt>();
        Zentra_Email_Config__mdt master = new Zentra_Email_Config__mdt(
            DeveloperName = 'Master', Is_Enabled__c = true,
            Brand_Color__c = '#1a237e', Accent_Color__c = '#4caf50', Bank_Name__c = 'Test Bank'
        );
        ZentraEmailService.configCache.put('Master', master);
    }

    @IsTest
    static void testSendEmailSummary_Balance() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'balance';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSendEmailSummary_Transaction() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'transaction';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSendEmailSummary_Recurring() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'recurring';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSendEmailSummary_MutualFund() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'mutualfund';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSendEmailSummary_InvalidType() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'invalid';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Invalid email type'));
    }

    @IsTest
    static void testSendEmailSummary_BlankCustomerId() {
        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = '';
        req.emailType = 'balance';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('required'));
    }

    @IsTest
    static void testSendEmailSummary_Dispute_WithDispute() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'dispute';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Case #'));
    }

    @IsTest
    static void testSendEmailSummary_Dispute_NoDisputes() {
        Account acct2 = new Account(Name = 'No Dispute Acct');
        insert acct2;

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct2.Id);
        req.emailType = 'dispute';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testSendEmailSummary_Loan_WithLoan() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'EmailSummary Test' LIMIT 1];

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'loan';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Request #'));
    }

    @IsTest
    static void testSendEmailSummary_Loan_NoLoans() {
        Account acct2 = new Account(Name = 'No Loan Acct');
        insert acct2;

        ZentraEmailSummaryService.EmailSummaryRequest req = new ZentraEmailSummaryService.EmailSummaryRequest();
        req.customerId = String.valueOf(acct2.Id);
        req.emailType = 'loan';

        Test.startTest();
        List<ZentraEmailSummaryService.EmailSummaryResult> results =
            ZentraEmailSummaryService.sendEmailSummary(
                new List<ZentraEmailSummaryService.EmailSummaryRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }
}
