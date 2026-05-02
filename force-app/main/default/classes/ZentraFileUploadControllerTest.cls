@IsTest
private class ZentraFileUploadControllerTest {

    @IsTest
    static void testUploadFile_WithRecordId() {
        Account acct = new Account(Name = 'Upload Test');
        insert acct;

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('test file content'));

        Test.startTest();
        String docId = ZentraFileUploadController.uploadFile('test.txt', base64Data, acct.Id);
        Test.stopTest();

        System.assertNotEquals(null, docId);

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :acct.Id AND ContentDocumentId = :docId
        ];
        System.assertEquals(1, links.size());
    }

    @IsTest
    static void testUploadFile_NoRecordId() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('test file'));

        Test.startTest();
        String docId = ZentraFileUploadController.uploadFile('test.txt', base64Data, null);
        Test.stopTest();

        System.assertNotEquals(null, docId);
    }

    @IsTest
    static void testUploadFile_BlankFileName() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('test'));
        Boolean gotError = false;

        Test.startTest();
        try {
            ZentraFileUploadController.uploadFile('', base64Data, null);
        } catch (AuraHandledException e) {
            gotError = true;
        }
        Test.stopTest();

        System.assertEquals(true, gotError);
    }

    @IsTest
    static void testUploadFile_BlankData() {
        Boolean gotError = false;

        Test.startTest();
        try {
            ZentraFileUploadController.uploadFile('test.txt', '', null);
        } catch (AuraHandledException e) {
            gotError = true;
        }
        Test.stopTest();

        System.assertEquals(true, gotError);
    }
}
