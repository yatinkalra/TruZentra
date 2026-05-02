/**
 * ZentraStopRecurringPaymentServiceTest
 * @description Unit tests for ZentraStopRecurringPaymentService — stopping/cancelling recurring payments.
 * @developer   BlueForce Team
 * @date        2026-04-20
 */
@IsTest
private class ZentraStopRecurringPaymentServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(
            FirstName = 'Test',
            LastName  = 'StopCustomer',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert acct;

        // Create contact for email
        Contact con = [SELECT Id, Email FROM Contact WHERE AccountId = :acct.Id LIMIT 1];
        con.Email = 'test.stop@example.com';
        update con;

        // Create a financial account
        FinServ__FinancialAccount__c fa = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Status__c = 'Active',
            FinServ__Balance__c = 50000
        );
        insert fa;

        // Active recurring payments
        Zentra_Recurring_Payment__c rp1 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = fa.Id,
            Payee_Name__c = 'Delhi Electricity Board',
            Amount__c = 2500.00,
            Frequency__c = 'Monthly',
            Start_Date__c = Date.today().addMonths(-6),
            Next_Payment_Date__c = Date.today().addDays(5),
            Status__c = 'Active',
            Payment_Purpose__c = 'Utility Bill'
        );

        Zentra_Recurring_Payment__c rp2 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = fa.Id,
            Payee_Name__c = 'HDFC Mutual Fund SIP',
            Amount__c = 10000.00,
            Frequency__c = 'Monthly',
            Start_Date__c = Date.today().addMonths(-12),
            Next_Payment_Date__c = Date.today().addDays(10),
            Status__c = 'Active',
            Payment_Purpose__c = 'SIP / Mutual Fund'
        );

        // Already cancelled payment
        Zentra_Recurring_Payment__c rp3 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Payee_Name__c = 'Old Insurance Co',
            Amount__c = 5000.00,
            Frequency__c = 'Yearly',
            Start_Date__c = Date.today().addYears(-2),
            Status__c = 'Cancelled',
            Payment_Purpose__c = 'Insurance Premium'
        );

        insert new List<Zentra_Recurring_Payment__c>{ rp1, rp2, rp3 };

        // Seed CMDT cache so email service doesn't fail
        ZentraEmailService.configCache = new Map<String, Zentra_Email_Config__mdt>{
            'Master' => new Zentra_Email_Config__mdt(
                DeveloperName = 'Master',
                Is_Enabled__c = true,
                Brand_Color__c = '#1a237e',
                Accent_Color__c = '#4caf50',
                Bank_Name__c = 'Zentra Bank'
            ),
            'Recurring_Payment_Cancelled' => new Zentra_Email_Config__mdt(
                DeveloperName = 'Recurring_Payment_Cancelled',
                Is_Enabled__c = true,
                Subject_Template__c = '{0} — Standing Instruction Cancelled ({1})',
                Heading__c = 'Standing Instruction Cancelled',
                Intro_Text__c = 'Your standing instruction has been cancelled.'
            )
        };
    }

    @IsTest
    static void testStopPayment_Success_English() {
        Account acct = [SELECT Id FROM Account WHERE LastName = 'StopCustomer' LIMIT 1];

        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = acct.Id;
        req.paymentIndex = 1;
        req.language = 'en';

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assert(results[0].message.contains('Cancelled'), 'Should contain confirmation');

        // Verify the record was actually updated
        List<Zentra_Recurring_Payment__c> cancelled = [
            SELECT Status__c FROM Zentra_Recurring_Payment__c
            WHERE Customer__c = :acct.Id AND Status__c = 'Cancelled'
        ];
        System.assert(cancelled.size() >= 2, 'Should have at least 2 cancelled payments (1 original + 1 just stopped)');
    }

    @IsTest
    static void testStopPayment_Success_Hindi() {
        Account acct = [SELECT Id FROM Account WHERE LastName = 'StopCustomer' LIMIT 1];

        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = acct.Id;
        req.paymentIndex = 1;
        req.language = 'hi';

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed in Hindi');
        System.assert(results[0].message.contains('रद्द'), 'Should contain Hindi cancellation text');
    }

    @IsTest
    static void testStopPayment_InvalidIndex() {
        Account acct = [SELECT Id FROM Account WHERE LastName = 'StopCustomer' LIMIT 1];

        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = acct.Id;
        req.paymentIndex = 99;
        req.language = 'en';

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail with invalid index');
        System.assert(results[0].message.contains('Invalid number'), 'Should show invalid number message');
    }

    @IsTest
    static void testStopPayment_ZeroIndex() {
        Account acct = [SELECT Id FROM Account WHERE LastName = 'StopCustomer' LIMIT 1];

        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = acct.Id;
        req.paymentIndex = 0;

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail with zero index');
        System.assert(results[0].message.contains('specify which payment'), 'Should ask for a number');
    }

    @IsTest
    static void testStopPayment_MissingCustomerId() {
        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = null;
        req.paymentIndex = 1;

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail without customer id');
        System.assert(results[0].message.contains('Customer Id is required'), 'Should show validation error');
    }

    @IsTest
    static void testStopPayment_NoActivePayments() {
        Account acct2 = new Account(
            FirstName = 'Empty',
            LastName  = 'NoPayments',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert acct2;

        ZentraStopRecurringPaymentService.StopPaymentRequest req = new ZentraStopRecurringPaymentService.StopPaymentRequest();
        req.customerId = acct2.Id;
        req.paymentIndex = 1;

        Test.startTest();
        List<ZentraStopRecurringPaymentService.StopPaymentResult> results =
            ZentraStopRecurringPaymentService.stopRecurringPayment(
                new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail with no active payments');
        System.assert(results[0].message.contains('No active recurring payments'), 'Should show not-found message');
    }
}