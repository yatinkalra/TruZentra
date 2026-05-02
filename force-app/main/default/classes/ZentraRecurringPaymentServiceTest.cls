/**
 * ZentraRecurringPaymentServiceTest
 * @description Unit tests for ZentraRecurringPaymentService — recurring payments / standing instructions.
 * @developer   BlueForce Team
 * @date        2026-04-20
 */
@IsTest
private class ZentraRecurringPaymentServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(
            FirstName = 'Test',
            LastName  = 'Customer',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert acct;

        // Create a financial account for source reference
        FinServ__FinancialAccount__c fa = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Status__c = 'Active',
            FinServ__Balance__c = 50000
        );
        insert fa;

        // Active recurring payment
        Zentra_Recurring_Payment__c rp1 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = fa.Id,
            Payee_Name__c = 'Delhi Electricity Board',
            Amount__c = 2500.00,
            Frequency__c = 'Monthly',
            Start_Date__c = Date.today().addMonths(-6),
            End_Date__c = Date.today().addMonths(6),
            Next_Payment_Date__c = Date.today().addDays(5),
            Last_Payment_Date__c = Date.today().addDays(-25),
            Status__c = 'Active',
            Payment_Purpose__c = 'Utility Bill',
            Remarks__c = 'Electricity bill auto-pay'
        );

        // Another active payment — no end date (indefinite)
        Zentra_Recurring_Payment__c rp2 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Source_Account__c = fa.Id,
            Payee_Name__c = 'HDFC Mutual Fund SIP',
            Amount__c = 10000.00,
            Frequency__c = 'Monthly',
            Start_Date__c = Date.today().addMonths(-12),
            Next_Payment_Date__c = Date.today().addDays(10),
            Last_Payment_Date__c = Date.today().addDays(-20),
            Status__c = 'Active',
            Payment_Purpose__c = 'SIP / Mutual Fund'
        );

        // Cancelled payment
        Zentra_Recurring_Payment__c rp3 = new Zentra_Recurring_Payment__c(
            Customer__c = acct.Id,
            Payee_Name__c = 'Old Insurance Co',
            Amount__c = 5000.00,
            Frequency__c = 'Yearly',
            Start_Date__c = Date.today().addYears(-2),
            End_Date__c = Date.today().addMonths(-1),
            Status__c = 'Cancelled',
            Payment_Purpose__c = 'Insurance Premium'
        );

        insert new List<Zentra_Recurring_Payment__c>{ rp1, rp2, rp3 };
    }

    @IsTest
    static void testGetActivePayments_English() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'en';
        req.includeInactive = false;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals(2, results[0].paymentCount, 'Should find 2 active payments');
        System.assert(results[0].summary.contains('Delhi Electricity Board'), 'Should contain payee name');
        System.assert(results[0].summary.contains('HDFC Mutual Fund SIP'), 'Should contain second payee');
        System.assert(results[0].summary.contains('Monthly'), 'Should contain frequency');
    }

    @IsTest
    static void testGetActivePayments_Hindi() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'hi';

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed in Hindi');
        System.assert(results[0].summary.contains('स्थायी निर्देश'), 'Should contain Hindi header');
        System.assert(results[0].summary.contains('मासिक'), 'Should contain Hindi frequency');
    }

    @IsTest
    static void testGetAllPayments_IncludeInactive() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'en';
        req.includeInactive = true;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed');
        System.assertEquals(3, results[0].paymentCount, 'Should find all 3 payments (including cancelled)');
        System.assert(results[0].summary.contains('Old Insurance Co'), 'Should contain cancelled payment');
    }

    @IsTest
    static void testNoPaymentsFound() {
        // Create a new account with no payments
        Account acct2 = new Account(
            FirstName = 'Empty',
            LastName  = 'Customer',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
        );
        insert acct2;

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct2.Id;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should return false when no payments');
        System.assertEquals(0, results[0].paymentCount, 'Count should be 0');
        System.assert(results[0].summary.contains('No active recurring payments'), 'Should show not-found message');
    }

    @IsTest
    static void testMissingCustomerId() {
        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = null;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail without customer id');
        System.assert(results[0].summary.contains('Customer Id is required'), 'Should show validation error');
    }

    @IsTest
    static void testDefaultLanguage() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        // language not set — should default to English

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed with default language');
        System.assert(results[0].summary.contains('Recurring Payments'), 'Should be in English by default');
    }

    @IsTest
    static void testPaymentDetail_English() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'en';
        req.paymentIndex = 1;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed for detail view');
        System.assert(results[0].summary.contains('Delhi Electricity Board'), 'Should contain payee in detail');
        System.assert(results[0].summary.contains('2500') || results[0].summary.contains('2,500'), 'Should contain amount');
    }

    @IsTest
    static void testPaymentDetail_IndefiniteEndDate() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'en';
        req.paymentIndex = 2;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed for indefinite detail');
        System.assert(results[0].summary.contains('Indefinite'), 'Should show Indefinite for no end date');
    }

    @IsTest
    static void testPaymentDetail_Hindi() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'hi';
        req.paymentIndex = 1;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Should succeed for Hindi detail');
    }

    @IsTest
    static void testPaymentDetail_InvalidIndex() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        ZentraRecurringPaymentService.RecurringPaymentRequest req = new ZentraRecurringPaymentService.RecurringPaymentRequest();
        req.customerId = acct.Id;
        req.language = 'en';
        req.paymentIndex = 99;

        Test.startTest();
        List<ZentraRecurringPaymentService.RecurringPaymentResult> results =
            ZentraRecurringPaymentService.getRecurringPayments(new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'Should fail for invalid index');
    }
}