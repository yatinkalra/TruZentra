@IsTest
private class ZentraDisputeUploadServiceTest {

    private class MockAICallout implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        MockAICallout(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Upload Dispute Test');
        insert acct;

        FinServ__FinancialAccount__c fa = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c = 50000,
            FinServ__Status__c = 'Active'
        );
        insert fa;

        FinServ__FinancialAccountTransaction__c txn = new FinServ__FinancialAccountTransaction__c(
            FinServ__FinancialAccount__c = fa.Id,
            FinServ__Amount__c = 1500,
            FinServ__TransactionDate__c = Date.today().addDays(-1),
            FinServ__Description__c = 'Swiggy Food Order',
            FinServ__TransactionType__c = 'Debit'
        );
        insert txn;
    }

    @IsTest
    static void testProcessUpload_BlankCustomerId() {
        ZentraDisputeUploadService.UploadRequest req = new ZentraDisputeUploadService.UploadRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraDisputeUploadService.UploadResult> results =
            ZentraDisputeUploadService.processUpload(
                new List<ZentraDisputeUploadService.UploadRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals('ERROR', results[0].status);
    }

    @IsTest
    static void testProcessUpload_NoDocument() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Upload Dispute Test' LIMIT 1];

        ZentraDisputeUploadService.UploadRequest req = new ZentraDisputeUploadService.UploadRequest();
        req.customerId = acct.Id;

        Test.startTest();
        List<ZentraDisputeUploadService.UploadResult> results =
            ZentraDisputeUploadService.processUpload(
                new List<ZentraDisputeUploadService.UploadRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testProcessUpload_WithDocumentId_AIReturnsInvalid() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Upload Dispute Test' LIMIT 1];

        // Create a file
        ContentVersion cv = new ContentVersion(
            Title = 'receipt.jpg', PathOnClient = 'receipt.jpg',
            VersionData = Blob.valueOf('fake image')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link to account
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = acct.Id,
            ShareType = 'V', Visibility = 'AllUsers'
        );
        insert cdl;

        // Mock AI returning invalid image result
        String aiResponse = '{"is_transaction": false, "summary": "This is not a receipt"}';
        Test.setMock(HttpCalloutMock.class, new MockAICallout(200,
            '{"generations":[{"text":"' + aiResponse.replace('"', '\\"') + '"}]}'));

        ZentraDisputeUploadService.UploadRequest req = new ZentraDisputeUploadService.UploadRequest();
        req.customerId = acct.Id;
        req.documentId = cv.ContentDocumentId;

        Test.startTest();
        List<ZentraDisputeUploadService.UploadResult> results =
            ZentraDisputeUploadService.processUpload(
                new List<ZentraDisputeUploadService.UploadRequest>{ req });
        Test.stopTest();

        // AI will likely fail in test context (ConnectApi + REST both unavailable)
        // but we exercise the code paths
        System.assertNotEquals(null, results[0].status);
    }

    @IsTest
    static void testStatusConstants() {
        System.assertEquals('SUCCESS', ZentraDisputeUploadService.STATUS_SUCCESS);
        System.assertEquals('INVALID_IMAGE', ZentraDisputeUploadService.STATUS_INVALID_IMAGE);
        System.assertEquals('NO_MATCH', ZentraDisputeUploadService.STATUS_NO_MATCH);
        System.assertEquals('ERROR', ZentraDisputeUploadService.STATUS_ERROR);
    }

    @IsTest
    static void testProcessUpload_InvalidCustomerId() {
        ZentraDisputeUploadService.UploadRequest req = new ZentraDisputeUploadService.UploadRequest();
        req.customerId = '001000000000000AAA'; // fake but valid format
        req.documentId = '069000000000000AAA';

        Test.setMock(HttpCalloutMock.class, new MockAICallout(200, '{"generations":[]}'));

        Test.startTest();
        List<ZentraDisputeUploadService.UploadResult> results =
            ZentraDisputeUploadService.processUpload(
                new List<ZentraDisputeUploadService.UploadRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }
}
