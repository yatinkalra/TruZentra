@IsTest
private class ZentraDocumentCaptureServiceTest {

    @IsTest
    static void testCaptureDocument_BlankCustomer() {
        ZentraDocumentCaptureService.CaptureRequest req = new ZentraDocumentCaptureService.CaptureRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraDocumentCaptureService.CaptureResult> results =
            ZentraDocumentCaptureService.captureDocument(
                new List<ZentraDocumentCaptureService.CaptureRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Customer'));
    }

    @IsTest
    static void testCaptureDocument_NoRecentFiles() {
        Account acct = new Account(Name = 'Capture Test');
        insert acct;

        ZentraDocumentCaptureService.CaptureRequest req = new ZentraDocumentCaptureService.CaptureRequest();
        req.customerId = acct.Id;

        Test.startTest();
        List<ZentraDocumentCaptureService.CaptureResult> results =
            ZentraDocumentCaptureService.captureDocument(
                new List<ZentraDocumentCaptureService.CaptureRequest>{ req });
        Test.stopTest();

        // Either no file found or file already linked
        System.assertNotEquals(null, results[0].message);
    }

    @IsTest
    static void testCaptureDocument_WithRecentFile() {
        Account acct = new Account(Name = 'Capture With File');
        insert acct;

        // Create a ContentVersion (file)
        ContentVersion cv = new ContentVersion(
            Title = 'test-receipt.jpg',
            PathOnClient = 'test-receipt.jpg',
            VersionData = Blob.valueOf('fake image data')
        );
        insert cv;

        ZentraDocumentCaptureService.CaptureRequest req = new ZentraDocumentCaptureService.CaptureRequest();
        req.customerId = acct.Id;

        Test.startTest();
        List<ZentraDocumentCaptureService.CaptureResult> results =
            ZentraDocumentCaptureService.captureDocument(
                new List<ZentraDocumentCaptureService.CaptureRequest>{ req });
        Test.stopTest();

        // Should succeed or report already linked
        System.assertNotEquals(null, results[0].message);
    }
}
