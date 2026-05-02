@IsTest
private class ZentraDisputeStatusServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'DisputeStatus Test');
        insert acct;

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            return;
        }

        Case c = new Case(
            AccountId = acct.Id,
            RecordTypeId = disputeRT,
            Subject = 'Dispute: Test Merchant ₹500',
            Dispute_Amount__c = 500,
            Dispute_Stage__c = 'Filed',
            Provisional_Credit_Issued__c = true,
            Provisional_Credit_Amount__c = 500,
            Estimated_Resolution_Date__c = Date.today().addDays(7)
        );
        insert c;
    }

    private static Id getDisputeRT() {
        try {
            return Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            return null;
        }
    }

    @IsTest
    static void testGetDisputeStatus_ListMode() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'DisputeStatus Test' LIMIT 1];

        ZentraDisputeStatusService.DisputeStatusRequest req = new ZentraDisputeStatusService.DisputeStatusRequest();
        req.customerId = String.valueOf(acct.Id);

        Test.startTest();
        List<ZentraDisputeStatusService.DisputeStatusResult> results =
            ZentraDisputeStatusService.getDisputeStatus(
                new List<ZentraDisputeStatusService.DisputeStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].disputeCount > 0);
        System.assert(results[0].statusSummary.contains('Dispute Cases'));
    }

    @IsTest
    static void testGetDisputeStatus_DetailMode() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'DisputeStatus Test' LIMIT 1];
        Case c = [SELECT CaseNumber FROM Case WHERE AccountId = :acct.Id LIMIT 1];

        ZentraDisputeStatusService.DisputeStatusRequest req = new ZentraDisputeStatusService.DisputeStatusRequest();
        req.customerId = String.valueOf(acct.Id);
        req.caseNumber = c.CaseNumber;

        Test.startTest();
        List<ZentraDisputeStatusService.DisputeStatusResult> results =
            ZentraDisputeStatusService.getDisputeStatus(
                new List<ZentraDisputeStatusService.DisputeStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(1, results[0].disputeCount);
        System.assert(results[0].statusSummary.contains('Dispute Detail'));
    }

    @IsTest
    static void testGetDisputeStatus_WrongCaseNumber() {
        if (getDisputeRT() == null) return;

        Account acct = [SELECT Id FROM Account WHERE Name = 'DisputeStatus Test' LIMIT 1];

        ZentraDisputeStatusService.DisputeStatusRequest req = new ZentraDisputeStatusService.DisputeStatusRequest();
        req.customerId = String.valueOf(acct.Id);
        req.caseNumber = '99999999';

        Test.startTest();
        List<ZentraDisputeStatusService.DisputeStatusResult> results =
            ZentraDisputeStatusService.getDisputeStatus(
                new List<ZentraDisputeStatusService.DisputeStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testGetDisputeStatus_NoCustomerId() {
        ZentraDisputeStatusService.DisputeStatusRequest req = new ZentraDisputeStatusService.DisputeStatusRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraDisputeStatusService.DisputeStatusResult> results =
            ZentraDisputeStatusService.getDisputeStatus(
                new List<ZentraDisputeStatusService.DisputeStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testGetDisputeStatus_NoDisputes() {
        Account noDispute = new Account(Name = 'No Disputes Acct');
        insert noDispute;

        ZentraDisputeStatusService.DisputeStatusRequest req = new ZentraDisputeStatusService.DisputeStatusRequest();
        req.customerId = String.valueOf(noDispute.Id);

        Test.startTest();
        List<ZentraDisputeStatusService.DisputeStatusResult> results =
            ZentraDisputeStatusService.getDisputeStatus(
                new List<ZentraDisputeStatusService.DisputeStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(0, results[0].disputeCount);
    }
}
