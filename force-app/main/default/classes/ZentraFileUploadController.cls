/**
 * Apex controller for the zentraFileUpload LWC.
 * Runs WITHOUT sharing so guest users can create ContentVersion records.
 * Receives base64 file data from the LWC and creates a ContentVersion,
 * then links it to the customer Account via ContentDocumentLink.
 */
public without sharing class ZentraFileUploadController {

    @AuraEnabled
    public static String uploadFile(String fileName, String base64Data, String recordId) {
        try {
            if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new AuraHandledException('File name and data are required.');
            }

            // Create ContentVersion (this auto-creates ContentDocument)
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = null; // Will be set via CDL
            insert cv;

            // Get the ContentDocumentId
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

            // Link to the customer Account if recordId provided
            if (String.isNotBlank(recordId)) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = cv.ContentDocumentId;
                cdl.LinkedEntityId = recordId;
                cdl.ShareType = 'V'; // Viewer
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }

            return cv.ContentDocumentId;

        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraFileUploadController', 'uploadFile', e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}