@IsTest
private class ZentraNewAccountServiceTest {

    private static Id getNewAccountRT() {
        try {
            return Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('New_Account_Opening').getRecordTypeId();
        } catch (Exception e) {
            return null;
        }
    }

    @IsTest
    static void testRequestNewAccount_Success() {
        if (getNewAccountRT() == null) return;

        ZentraNewAccountService.NewAccountRequest req = new ZentraNewAccountService.NewAccountRequest();
        req.phoneNumber = '+919876543210';
        req.customerName = 'Rajesh Sharma';
        req.customerEmail = 'rajesh@test.com';

        Test.startTest();
        List<ZentraNewAccountService.NewAccountResult> results =
            ZentraNewAccountService.requestNewAccount(
                new List<ZentraNewAccountService.NewAccountRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertNotEquals(null, results[0].caseNumber);
        System.assertNotEquals(null, results[0].rmCallbackTime);
    }

    @IsTest
    static void testRequestNewAccount_MissingPhone() {
        if (getNewAccountRT() == null) return;

        ZentraNewAccountService.NewAccountRequest req = new ZentraNewAccountService.NewAccountRequest();
        req.phoneNumber = '';
        req.customerName = 'Test';
        req.customerEmail = 'test@test.com';

        Test.startTest();
        List<ZentraNewAccountService.NewAccountResult> results =
            ZentraNewAccountService.requestNewAccount(
                new List<ZentraNewAccountService.NewAccountRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Phone'));
    }

    @IsTest
    static void testRequestNewAccount_MissingName() {
        if (getNewAccountRT() == null) return;

        ZentraNewAccountService.NewAccountRequest req = new ZentraNewAccountService.NewAccountRequest();
        req.phoneNumber = '+919876543210';
        req.customerName = '';
        req.customerEmail = 'test@test.com';

        Test.startTest();
        List<ZentraNewAccountService.NewAccountResult> results =
            ZentraNewAccountService.requestNewAccount(
                new List<ZentraNewAccountService.NewAccountRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('name'));
    }

    @IsTest
    static void testRequestNewAccount_MissingEmail() {
        if (getNewAccountRT() == null) return;

        ZentraNewAccountService.NewAccountRequest req = new ZentraNewAccountService.NewAccountRequest();
        req.phoneNumber = '+919876543210';
        req.customerName = 'Test User';
        req.customerEmail = '';

        Test.startTest();
        List<ZentraNewAccountService.NewAccountResult> results =
            ZentraNewAccountService.requestNewAccount(
                new List<ZentraNewAccountService.NewAccountRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('email'));
    }
}
