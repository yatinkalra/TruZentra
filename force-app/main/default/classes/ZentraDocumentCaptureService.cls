/**
 * ZentraDocumentCaptureService - Links an uploaded document/image to the customer's Account record.
 * When a customer uploads a screenshot or receipt in the WhatsApp chat,
 * this service auto-detects the most recently uploaded file and creates
 * a ContentDocumentLink so it appears on the Account's Files related list.
 * No document IDs need to be passed — the service finds them automatically.
 * @author  BlueForce Team
 * @date    2026-04-16
 */
public without sharing class ZentraDocumentCaptureService {

    @InvocableMethod(label='Capture Document to Account' description='Auto-detects the most recently uploaded image/document and links it to the customer Account record. Only requires the Customer Account Id.' category='Document Management')
    public static List<CaptureResult> captureDocument(List<CaptureRequest> requests) {
        List<CaptureResult> results = new List<CaptureResult>();

        for (CaptureRequest req : requests) {
            CaptureResult r = new CaptureResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer not identified. Please verify your identity first.';
                    results.add(r);
                    continue;
                }

                // Auto-detect: find the most recent ContentVersion uploaded in
                // the last 10 minutes that is NOT yet linked to this Account
                List<ContentVersion> recentFiles = [
                    SELECT Id, ContentDocumentId, Title, FileType, FileExtension,
                           ContentSize, CreatedDate
                    FROM ContentVersion
                    WHERE CreatedDate >= :Datetime.now().addMinutes(-10)
                      AND IsLatest = true
                      AND FileExtension IN ('jpg','jpeg','png','gif','bmp','webp','pdf','heic','heif','tiff','svg')
                    ORDER BY CreatedDate DESC
                    LIMIT 5
                ];

                if (recentFiles.isEmpty()) {
                    // Broader search: any file in last 30 minutes
                    recentFiles = [
                        SELECT Id, ContentDocumentId, Title, FileType, FileExtension,
                               ContentSize, CreatedDate
                        FROM ContentVersion
                        WHERE CreatedDate >= :Datetime.now().addMinutes(-30)
                          AND IsLatest = true
                        ORDER BY CreatedDate DESC
                        LIMIT 5
                    ];
                }

                if (recentFiles.isEmpty()) {
                    r.success = false;
                    r.message = 'No recently uploaded document found. Please upload an image or file and try again.';
                    results.add(r);
                    continue;
                }

                // Find the first file not already linked to this Account
                String targetDocId = null;
                String targetTitle = 'Document';
                for (ContentVersion cv : recentFiles) {
                    List<ContentDocumentLink> alreadyLinked = [
                        SELECT Id FROM ContentDocumentLink
                        WHERE ContentDocumentId = :cv.ContentDocumentId
                          AND LinkedEntityId = :req.customerId
                        LIMIT 1
                    ];
                    if (alreadyLinked.isEmpty()) {
                        targetDocId = cv.ContentDocumentId;
                        targetTitle = cv.Title;
                        break;
                    }
                }

                if (targetDocId == null) {
                    // All recent files are already linked
                    r.success = true;
                    r.message = 'Your most recent upload is already saved to your account records.';
                    results.add(r);
                    continue;
                }

                // Create the link
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = targetDocId,
                    LinkedEntityId    = req.customerId,
                    ShareType         = 'V',
                    Visibility        = 'AllUsers'
                );
                insert cdl;

                r.success = true;
                r.message = 'Successfully saved "' + targetTitle + '" to your account records.';
                r.contentDocumentLinkId = cdl.Id;

            } catch (Exception e) {
                r.success = false;
                r.message = 'Unable to save document: ' + e.getMessage();
            }
            results.add(r);
        }
        return results;
    }

    public class CaptureRequest {
        @InvocableVariable(label='Customer Account Id' description='The Account Id of the verified customer.' required=true)
        public String customerId;
    }

    public class CaptureResult {
        @InvocableVariable(label='Success' description='Whether the document was linked successfully.')
        public Boolean success;

        @InvocableVariable(label='Message' description='Confirmation or error message.')
        public String message;

        @InvocableVariable(label='Content Document Link Id' description='Id of the created ContentDocumentLink record.')
        public String contentDocumentLinkId;
    }
}