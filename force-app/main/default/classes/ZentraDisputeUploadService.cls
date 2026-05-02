/**
 * ZentraDisputeUploadService - Processes image uploads from the Zentra Dispute Upload screen flow.
 * Accepts customerId and optional documentId. If documentId is provided (from file upload component),
 * uses it directly. Otherwise falls back to querying ContentDocumentLink.
 * Invokes ZentraProcessImage prompt template via ConnectApi, parses JSON, validates, matches txn, files dispute.
 * Runs as without sharing so guest user SOQL on ContentDocumentLink/ContentDocument works.
 * @author  BlueForce Team
 * @date    2026-04-22
 */
public without sharing class ZentraDisputeUploadService {

    private static final String PROMPT_TEMPLATE_NAME = 'ZentraProcessImage';

    // Status codes returned to the flow for decision branching
    public static final String STATUS_SUCCESS       = 'SUCCESS';
    public static final String STATUS_INVALID_IMAGE = 'INVALID_IMAGE';
    public static final String STATUS_NO_MATCH      = 'NO_MATCH';
    public static final String STATUS_ERROR         = 'ERROR';

    @InvocableMethod(label='Process Dispute Document Upload'
        description='Finds uploaded document, invokes AI analysis, validates, finds matching transaction, and files a dispute. Used by the Zentra Dispute Upload screen flow.')
    public static List<UploadResult> processUpload(List<UploadRequest> requests) {
        List<UploadResult> results = new List<UploadResult>();
        // Collect debug messages — logged AFTER callout to avoid DML-before-callout error
        List<String> debugLog = new List<String>();

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            UploadResult errResult = new UploadResult();
            errResult.success = false;
            errResult.status = STATUS_ERROR;
            errResult.message = 'Dispute record type not configured. Please contact support.';
            results.add(errResult);
            // Log after returning (no callout needed)
            ZentraErrorLogger.log('ZentraDisputeUploadService', 'processUpload', e);
            return results;
        }

        for (UploadRequest req : requests) {
            UploadResult r = new UploadResult();
            try {
                debugLog.add('START — customerId=' + req.customerId + ', documentId=' + req.documentId);

                // ── Phase 1: Read-only queries + callout (NO DML before this) ──

                // Validate customer
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.status = STATUS_ERROR;
                    r.message = 'Customer not identified. This link may have expired. Please request a new upload link from the assistant.';
                    results.add(r);
                    continue;
                }

                List<Account> accts = [SELECT Id, Name FROM Account WHERE Id = :req.customerId LIMIT 1];
                if (accts.isEmpty()) {
                    r.success = false;
                    r.status = STATUS_ERROR;
                    r.message = 'Customer account not found. Please contact support.';
                    results.add(r);
                    continue;
                }

                // Step 1: Resolve ContentDocument Id
                String contentDocId = null;
                if (String.isNotBlank(req.documentId)) {
                    contentDocId = req.documentId;
                    debugLog.add('Step1: Using documentId from flow: ' + contentDocId);
                } else {
                    contentDocId = findLatestDocument(req.customerId);
                    debugLog.add('Step1: CDL query result: ' + contentDocId);
                }

                if (String.isBlank(contentDocId)) {
                    r.success = false;
                    r.status = STATUS_ERROR;
                    r.message = 'No uploaded document found. Please upload a transaction receipt or invoice first.';
                    results.add(r);
                    continue;
                }

                // Step 2: Invoke AI prompt template (HTTP callout — NO DML before this)
                debugLog.add('Step2: Invoking prompt with docId=' + contentDocId);
                String aiResponse = invokePromptTemplate(contentDocId);
                debugLog.add('Step2: AI response length=' + (aiResponse != null ? String.valueOf(aiResponse.length()) : 'NULL'));

                // ── Phase 2: DML is now allowed (callout is done) ──

                // Flush debug logs now that callout is complete
                ZentraErrorLogger.log('ZentraDisputeUploadService', 'processUpload',
                    String.join(debugLog, ' | '), null, 'Info',
                    String.isNotBlank(req.customerId) ? Id.valueOf(req.customerId) : null);
                debugLog.clear();

                if (String.isBlank(aiResponse)) {
                    r.success = false;
                    r.status = STATUS_ERROR;
                    r.message = 'AI analysis is temporarily unavailable. Please try again later or use TruZentra WhatsApp for assistance.';
                    results.add(r);
                    continue;
                }

                // Step 3: Parse the AI analysis JSON
                AnalysisData analysis = parseAnalysis(aiResponse);

                ZentraErrorLogger.log('ZentraDisputeUploadService', 'processUpload',
                    'Step3: isTransaction=' + (analysis != null ? String.valueOf(analysis.isTransaction) : 'NULL')
                    + ', amount=' + (analysis != null ? String.valueOf(analysis.amount) : 'NULL')
                    + ', merchant=' + (analysis != null ? analysis.merchant : 'NULL'),
                    null, 'Info', Id.valueOf(req.customerId));

                if (analysis == null || !analysis.isTransaction) {
                    r.success = false;
                    r.status = STATUS_INVALID_IMAGE;
                    r.analysisText = aiResponse;
                    r.message = 'Our AI could not verify your image as a valid transaction receipt or invoice. '
                        + 'Please try again with a clear photo of your transaction receipt, or use TruZentra WhatsApp for assistance.';
                    results.add(r);
                    continue;
                }

                // Step 4: Find the matching transaction in the database
                FinServ__FinancialAccountTransaction__c txn = findTransaction(
                    req.customerId, analysis.amount, analysis.merchant);

                if (txn == null) {
                    r.success = false;
                    r.status = STATUS_NO_MATCH;
                    r.analysisText = aiResponse;
                    r.message = 'We could not find a matching transaction of ₹' + analysis.amount
                        + (String.isNotBlank(analysis.merchant) ? ' at ' + analysis.merchant : '')
                        + ' on your account. If you believe this is an error, please contact TruZentra support or visit your nearest branch.';
                    results.add(r);
                    continue;
                }

                // Step 5: File the dispute
                r = createDisputeCase(req.customerId, txn, analysis, disputeRT);
                results.add(r);

            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraDisputeUploadService', 'processUpload', e,
                    String.isNotBlank(req.customerId) ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.status = STATUS_ERROR;
                r.message = 'An error occurred while processing your dispute. Please try again or contact support.';
                results.add(r);
            }
        }

        // Flush any remaining debug messages
        if (!debugLog.isEmpty()) {
            ZentraErrorLogger.log('ZentraDisputeUploadService', 'processUpload',
                String.join(debugLog, ' | '), null, 'Info', null);
        }

        return results;
    }

    /**
     * Finds the most recently uploaded ContentDocument linked to the customer Account.
     * Looks for files uploaded in the last 15 minutes.
     */
    private static String findLatestDocument(String customerId) {
        if (String.isBlank(customerId)) return null;

        DateTime cutoff = DateTime.now().addMinutes(-15);
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :customerId
              AND ContentDocument.CreatedDate >= :cutoff
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];

        if (links.isEmpty()) {
            return null;
        }

        return links[0].ContentDocumentId;
    }

    /**
     * Invokes the ZentraProcessImage prompt template.
     * Tries ConnectApi first (works for guest users without REST session).
     * Falls back to REST API if ConnectApi fails.
     * Returns the raw AI response text, or null on failure.
     */
    private static String invokePromptTemplate(String contentDocumentId) {
        // Try ConnectApi first (no session token needed — works for guest users)
        String connectApiResult = invokeViaConnectApi(contentDocumentId);
        if (String.isNotBlank(connectApiResult)) {
            return connectApiResult;
        }

        // Fall back to REST API (requires valid session — works for admin)
        return invokeViaRestApi(contentDocumentId);
    }

    private static String invokeViaConnectApi(String contentDocumentId) {
        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            genInput.isPreview = false;

            Map<String, ConnectApi.WrappedValue> inputParams =
                new Map<String, ConnectApi.WrappedValue>();

            // Pass as a Map with 'id' key — mirrors what works in the REST API
            ConnectApi.WrappedValue imageVal = new ConnectApi.WrappedValue();
            imageVal.value = new Map<String, String>{ 'id' => contentDocumentId };
            inputParams.put('Input:imageUpload', imageVal);

            genInput.inputParams = inputParams;
            genInput.additionalConfig = new ConnectApi.EinsteinLLMAdditionalConfigInput();
            genInput.additionalConfig.applicationName = 'PromptBuilderPreview';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    PROMPT_TEMPLATE_NAME, genInput
                );

            if (result != null && result.generations != null && !result.generations.isEmpty()) {
                String text = result.generations[0].text;
                return text;
            }

            return null;

        } catch (Exception e) {
            // Silently fail — REST API fallback will handle it (no DML here to avoid blocking callout)
            return null;
        }
    }

    private static String invokeViaRestApi(String contentDocumentId) {
        try {
            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            String endpoint = baseUrl + '/services/data/v65.0/einstein/prompt-templates/'
                + PROMPT_TEMPLATE_NAME + '/generations';

            Map<String, Object> body = new Map<String, Object>{
                'isPreview' => false,
                'inputParams' => new Map<String, Object>{
                    'valueMap' => new Map<String, Object>{
                        'Input:imageUpload' => new Map<String, Object>{
                            'value' => new Map<String, String>{ 'id' => contentDocumentId }
                        }
                    }
                },
                'additionalConfig' => new Map<String, Object>{
                    'applicationName' => 'PromptBuilderPreview'
                }
            };

            // Get auth token — VF session for admin, OAuth Client Credentials for guest
            String authToken = getAuthToken();
            if (String.isBlank(authToken)) {
                ZentraErrorLogger.log('ZentraDisputeUploadService', 'invokeViaRestApi',
                    'No auth token available — both session and OAuth failed. Guest user may need Connected App configured in Zentra AI Config.',
                    null, 'Error', null);
                return null;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + authToken);
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                ZentraErrorLogger.log('ZentraDisputeUploadService', 'invokeViaRestApi',
                    'HTTP ' + res.getStatusCode() + ': ' + res.getBody().left(500),
                    null, 'Error', null);
                return null;
            }

            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> generations = (List<Object>) result.get('generations');

            if (generations == null || generations.isEmpty()) {
                List<Object> errors = (List<Object>) result.get('generationErrors');
                String errMsg = errors != null ? JSON.serialize(errors).left(500) : 'none';
                ZentraErrorLogger.log('ZentraDisputeUploadService', 'invokeViaRestApi',
                    'No generations. Errors: ' + errMsg, null, 'Error', null);
                return null;
            }

            Map<String, Object> gen = (Map<String, Object>) generations[0];
            return (String) gen.get('text');

        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraDisputeUploadService', 'invokeViaRestApi',
                'EXCEPTION: ' + e.getTypeName() + ' — ' + e.getMessage(),
                e.getStackTraceString(), 'Error', null);
            return null;
        }
    }

    /**
     * Parses the AI analysis JSON returned by ZentraProcessImage prompt template.
     */
    private static AnalysisData parseAnalysis(String analysisJson) {
        if (String.isBlank(analysisJson)) return null;

        try {
            // Strip markdown code fences if present
            String cleaned = analysisJson.trim();
            if (cleaned.startsWith('```')) {
                Integer firstNewline = cleaned.indexOf('\n');
                if (firstNewline > 0) cleaned = cleaned.substring(firstNewline + 1);
                if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.lastIndexOf('```'));
                cleaned = cleaned.trim();
            }

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

            AnalysisData data = new AnalysisData();
            data.isTransaction = parsed.get('is_transaction') == true;
            data.merchant = parsed.containsKey('merchant') && parsed.get('merchant') != null
                ? String.valueOf(parsed.get('merchant')) : null;
            data.summary = parsed.containsKey('summary') && parsed.get('summary') != null
                ? String.valueOf(parsed.get('summary')) : null;
            data.transactionDate = parsed.containsKey('transaction_date') && parsed.get('transaction_date') != null
                ? String.valueOf(parsed.get('transaction_date')) : null;
            data.referenceId = parsed.containsKey('reference_id') && parsed.get('reference_id') != null
                ? String.valueOf(parsed.get('reference_id')) : null;
            data.transactionType = parsed.containsKey('transaction_type') && parsed.get('transaction_type') != null
                ? String.valueOf(parsed.get('transaction_type')) : null;

            if (parsed.containsKey('amount') && parsed.get('amount') != null) {
                data.amount = Decimal.valueOf(String.valueOf(parsed.get('amount')));
            }

            return data;
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraDisputeUploadService', 'parseAnalysis',
                'Failed to parse AI JSON: ' + e.getMessage(), e.getStackTraceString(), 'Warning', null);
            return null;
        }
    }

    private static FinServ__FinancialAccountTransaction__c findTransaction(
            String customerId, Decimal amount, String merchant) {
        if (amount == null) return null;

        // Try with merchant filter first, then without
        String merchantFilter = String.isNotBlank(merchant) ? '%' + merchant + '%' : null;

        List<FinServ__FinancialAccountTransaction__c> txns;

        if (merchantFilter != null) {
            txns = [
                SELECT Id, Name, FinServ__Amount__c, FinServ__TransactionDate__c,
                       FinServ__Description__c, FinServ__FinancialAccount__c,
                       FinServ__FinancialAccount__r.Name,
                       FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c
                FROM FinServ__FinancialAccountTransaction__c
                WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :customerId
                  AND FinServ__Amount__c = :amount
                  AND FinServ__Description__c LIKE :merchantFilter
                ORDER BY FinServ__TransactionDate__c DESC
                LIMIT 1
            ];
        }

        // If no result with merchant, try amount-only match
        if (txns == null || txns.isEmpty()) {
            txns = [
                SELECT Id, Name, FinServ__Amount__c, FinServ__TransactionDate__c,
                       FinServ__Description__c, FinServ__FinancialAccount__c,
                       FinServ__FinancialAccount__r.Name,
                       FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c
                FROM FinServ__FinancialAccountTransaction__c
                WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :customerId
                  AND FinServ__Amount__c = :amount
                ORDER BY FinServ__TransactionDate__c DESC
                LIMIT 1
            ];
        }

        return txns.isEmpty() ? null : txns[0];
    }

    private static UploadResult createDisputeCase(String customerId,
            FinServ__FinancialAccountTransaction__c txn, AnalysisData analysis, Id disputeRT) {
        UploadResult r = new UploadResult();

        // Mark transaction as disputed
        txn.FinServ__IsDisputed__c = true;
        txn.FinServ__DisputeReason__c = 'Transaction not recognized';
        update txn;

        String merchantDisplay = txn.FinServ__Description__c != null
            ? txn.FinServ__Description__c : (String.isNotBlank(analysis.merchant) ? analysis.merchant : 'Unknown');

        Case dispute = new Case(
            RecordTypeId = disputeRT,
            AccountId = customerId,
            Disputed_Transaction__c = txn.Id,
            Dispute_Amount__c = txn.FinServ__Amount__c,
            Dispute_Stage__c = 'Filed',
            Provisional_Credit_Issued__c = true,
            Provisional_Credit_Amount__c = txn.FinServ__Amount__c,
            Estimated_Resolution_Date__c = Date.today().addDays(7),
            Subject = 'Dispute: ' + merchantDisplay + ' ₹' + txn.FinServ__Amount__c,
            Description = 'Source: Document Upload (AI-Verified)\n'
                + 'Merchant: ' + merchantDisplay + '\n'
                + 'Amount: ₹' + txn.FinServ__Amount__c + '\n'
                + 'Date: ' + (txn.FinServ__TransactionDate__c != null ? String.valueOf(txn.FinServ__TransactionDate__c) : '—') + '\n'
                + (String.isNotBlank(analysis.transactionType) ? 'Type: ' + analysis.transactionType + '\n' : '')
                + (String.isNotBlank(analysis.referenceId) ? 'Reference: ' + analysis.referenceId + '\n' : '')
                + '\n── AI Image Analysis ──\n'
                + (String.isNotBlank(analysis.summary) ? analysis.summary : '')
        );
        insert dispute;

        String caseNumber = [SELECT CaseNumber FROM Case WHERE Id = :dispute.Id LIMIT 1].CaseNumber;

        r.success = true;
        r.status = STATUS_SUCCESS;
        r.caseNumber = caseNumber;
        r.disputeAmount = txn.FinServ__Amount__c;
        r.estimatedResolutionDate = Date.today().addDays(7).format();
        r.analysisText = (String.isNotBlank(analysis.summary) ? analysis.summary : '');
        r.message = 'Dispute filed successfully for ₹' + txn.FinServ__Amount__c + ' at ' + merchantDisplay + '.';

        // Send confirmation email
        ZentraEmailService.sendDisputeConfirmationEmail(
            customerId,
            caseNumber,
            txn.FinServ__Amount__c,
            merchantDisplay,
            Date.today().addDays(7).format()
        );

        return r;
    }

    // Inner class for parsed AI analysis
    private class AnalysisData {
        Boolean isTransaction = false;
        Decimal amount;
        String merchant;
        String transactionDate;
        String referenceId;
        String transactionType;
        String summary;
    }

    /**
     * Returns an auth token for REST API calls.
     * Tries VF-page session first (works for admin users),
     * then falls back to OAuth Client Credentials (works for guest users).
     */
    private static String getAuthToken() {
        // 1) Try VF page session (admin / internal users)
        try {
            String vfSession = Page.ZentraSessionHelper.getContent().toString().trim();
            if (String.isNotBlank(vfSession) && vfSession != 'null') {
                return vfSession;
            }
        } catch (Exception e) {
            // VF page not accessible (guest user) — fall through
        }

        // 2) Try UserInfo session
        String uiSession = UserInfo.getSessionId();
        if (String.isNotBlank(uiSession)) {
            return uiSession;
        }

        // 3) Fall back to OAuth Client Credentials flow
        return getOAuthToken();
    }

    /**
     * Gets an access token using OAuth 2.0 Client Credentials flow.
     * Reads Connected App credentials from Zentra_AI_Config__mdt.
     * This allows guest users (who have no session) to make REST API calls.
     */
    private static String getOAuthToken() {
        try {
            Zentra_AI_Config__mdt config = Zentra_AI_Config__mdt.getInstance('Default');
            if (config == null || String.isBlank(config.Client_Id__c) || String.isBlank(config.Client_Secret__c)) {
                return null;
            }

            String baseUrl = URL.getOrgDomainUrl().toExternalForm();
            HttpRequest tokenReq = new HttpRequest();
            tokenReq.setEndpoint(baseUrl + '/services/oauth2/token');
            tokenReq.setMethod('POST');
            tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            tokenReq.setBody(
                'grant_type=client_credentials' +
                '&client_id=' + EncodingUtil.urlEncode(config.Client_Id__c, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(config.Client_Secret__c, 'UTF-8')
            );
            tokenReq.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(tokenReq);

            if (res.getStatusCode() == 200) {
                Map<String, Object> tokenResult = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) tokenResult.get('access_token');
            }

            // Don't log here — avoid DML before the subsequent Einstein callout
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    public class UploadRequest {
        @InvocableVariable(required=true description='The Account Id of the verified customer.')
        public String customerId;

        @InvocableVariable(description='ContentDocument Id from the file upload component. If provided, skips ContentDocumentLink query.')
        public String documentId;
    }

    public class UploadResult {
        @InvocableVariable(description='Whether the dispute was filed successfully.')
        public Boolean success;

        @InvocableVariable(description='Status code: SUCCESS, INVALID_IMAGE, NO_MATCH, or ERROR.')
        public String status;

        @InvocableVariable(description='The Case Number for reference.')
        public String caseNumber;

        @InvocableVariable(description='The amount being disputed.')
        public Decimal disputeAmount;

        @InvocableVariable(description='Expected resolution date string.')
        public String estimatedResolutionDate;

        @InvocableVariable(description='Human-readable result message.')
        public String message;

        @InvocableVariable(description='AI analysis summary text.')
        public String analysisText;
    }
}