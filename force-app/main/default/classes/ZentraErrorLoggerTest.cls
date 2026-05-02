@IsTest
private class ZentraErrorLoggerTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Error Logger Test');
        insert acct;
    }

    @IsTest
    static void testLogWithException() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ZentraErrorLogger.log('TestClass', 'testMethod', e, acct.Id);
        }
        Test.stopTest();
        List<Zentra_Error_Log__c> logs = [SELECT Id, Source_Class__c, Method__c FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created');
        System.assertEquals('TestClass', logs[0].Source_Class__c);
    }

    @IsTest
    static void testLogWithExceptionNoCustomer() {
        Test.startTest();
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ZentraErrorLogger.log('TestClass', 'testMethod', e);
        }
        Test.stopTest();
        List<Zentra_Error_Log__c> logs = [SELECT Id FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created without customer');
    }

    @IsTest
    static void testLogWithMessageOnly() {
        Test.startTest();
        ZentraErrorLogger.log('TestClass', 'testMethod', 'Something went wrong');
        Test.stopTest();
        List<Zentra_Error_Log__c> logs = [SELECT Id, Error_Message__c FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty(), 'Error log should be created from message');
    }

    @IsTest
    static void testLogWithFullParams() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        ZentraErrorLogger.log('TestClass', 'testMethod', 'Error msg', 'stack trace', 'Warning', acct.Id);
        Test.stopTest();
        List<Zentra_Error_Log__c> logs = [SELECT Id, Severity__c FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty());
        System.assertEquals('Warning', logs[0].Severity__c);
    }

    @IsTest
    static void testErrorLoggerAction() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        ZentraErrorLoggerAction.ErrorLogRequest req = new ZentraErrorLoggerAction.ErrorLogRequest();
        req.sourceClass = 'TestFlow';
        req.method = 'faultPath';
        req.errorMessage = 'Flow error occurred';
        req.stackTrace = 'at line 5';
        req.severity = 'Warning';
        req.customerId = String.valueOf(acct.Id);

        Test.startTest();
        ZentraErrorLoggerAction.logError(new List<ZentraErrorLoggerAction.ErrorLogRequest>{ req });
        Test.stopTest();

        List<Zentra_Error_Log__c> logs = [SELECT Id, Source_Class__c FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty());
        System.assertEquals('TestFlow', logs[0].Source_Class__c);
    }

    @IsTest
    static void testErrorLoggerActionDefaultSeverity() {
        ZentraErrorLoggerAction.ErrorLogRequest req = new ZentraErrorLoggerAction.ErrorLogRequest();
        req.sourceClass = 'TestFlow';
        req.errorMessage = 'Error';

        Test.startTest();
        ZentraErrorLoggerAction.logError(new List<ZentraErrorLoggerAction.ErrorLogRequest>{ req });
        Test.stopTest();

        List<Zentra_Error_Log__c> logs = [SELECT Id, Severity__c FROM Zentra_Error_Log__c];
        System.assert(!logs.isEmpty());
        System.assertEquals('Error', logs[0].Severity__c);
    }
}
