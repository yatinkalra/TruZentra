@IsTest
private class ZentraResendConfirmationServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Resend Test Customer');
        insert acct;

        Contact con = new Contact(
            LastName = 'ResendTest', FirstName = 'Test',
            Email = 'resend.test@example.com', AccountId = acct.Id
        );
        insert con;

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        insert savings;

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
            Estimated_Resolution_Date__c = Date.today().addDays(7)
        );
        insert dispute;

        Loan_Restructuring_Request__c lrr = new Loan_Restructuring_Request__c(
            Customer__c = acct.Id,
            Loan_Financial_Account__c = loan.Id,
            Selected_Option__c = 'A',
            Original_EMI__c = 16200,
            New_EMI__c = 14500,
            New_Tenure_Months__c = 48,
            Additional_Interest__c = 25000,
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
    static void testResend_Balance() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Resend Test Customer' LIMIT 1];

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'balance';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testResend_InvalidType() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Resend Test Customer' LIMIT 1];

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'invalid';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Invalid'));
    }

    @IsTest
    static void testResend_BlankCustomerId() {
        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = '';
        req.emailType = 'balance';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testResend_Dispute_WithDispute() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Resend Test Customer' LIMIT 1];

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'dispute';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Case #'));
    }

    @IsTest
    static void testResend_Dispute_NoDisputes() {
        Account acct2 = new Account(Name = 'No Dispute Acct');
        insert acct2;

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct2.Id);
        req.emailType = 'dispute';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testResend_Loan_WithLoan() {
        injectMockConfig();
        Account acct = [SELECT Id FROM Account WHERE Name = 'Resend Test Customer' LIMIT 1];

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct.Id);
        req.emailType = 'loan';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].message.contains('Request #'));
    }

    @IsTest
    static void testResend_Loan_NoLoans() {
        Account acct2 = new Account(Name = 'No Loan Acct');
        insert acct2;

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct2.Id);
        req.emailType = 'loan';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testResend_Balance_NoAccounts() {
        Account acct2 = new Account(Name = 'No FA Acct');
        insert acct2;

        ZentraResendConfirmationService.ResendRequest req = new ZentraResendConfirmationService.ResendRequest();
        req.customerId = String.valueOf(acct2.Id);
        req.emailType = 'balance';

        Test.startTest();
        List<ZentraResendConfirmationService.ResendResult> results =
            ZentraResendConfirmationService.resendConfirmation(
                new List<ZentraResendConfirmationService.ResendRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }
}
