/**
 * @description Invocable Apex service to generate and send OTP for customer authentication.
 *              Designed to be called from Flows and Agentforce Actions.
 *              Creates an Zentra_OTP_Session__c record and sends OTP via branded email.
 *              SMS is mock in hackathon.
 * @author      BlueForce Team
 * @date        2026-04-10
 */
public without sharing class ZentraOTPService {

    private static final Integer OTP_LENGTH = 6;
    private static final Integer OTP_EXPIRY_MINUTES = 5;
    private static final Integer MAX_ACTIVE_SESSIONS = 3;
    private static final String MOCK_OTP = '123456';

    /**
     * @description Input wrapper for the invocable method — used by Flow / Agentforce.
     */
    public class OTPRequest {
        @InvocableVariable(label='Phone Number' description='Customer registered mobile number' required=true)
        public String phoneNumber;

        @InvocableVariable(label='Account Id' description='Account record Id of the customer' required=true)
        public Id accountId;

        @InvocableVariable(label='Channel' description='Channel: WhatsApp or SMS' required=false)
        public String channel;

        @InvocableVariable(label='Purpose' description='OTP purpose: login (default) or Loan_Restructuring_OTP. Controls email template used.' required=false)
        public String purpose;

    }

    /**
     * @description Output wrapper returned to Flow / Agentforce.
     */
    public class OTPResponse {
        @InvocableVariable(label='Success' description='Whether OTP was generated and sent successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-facing response message')
        public String message;

        @InvocableVariable(label='OTP Session Id' description='Id of the created Zentra_OTP_Session__c record')
        public Id otpSessionId;

        @InvocableVariable(label='Expires At' description='DateTime when the OTP expires')
        public DateTime expiresAt;
    }

    /**
     * @description Generates a 6-digit OTP, creates an Zentra_OTP_Session__c record, and sends the OTP.
     *              Bulkified to accept a list of requests.
     * @param requests List of OTPRequest from Flow
     * @return List of OTPResponse with success status and session details
     */
    @InvocableMethod(label='Send OTP' description='Generates and sends a 6-digit OTP to the customer phone number. Creates an Zentra_OTP_Session__c record.' category='Authentication')
    public static List<OTPResponse> sendOTP(List<OTPRequest> requests) {
        List<OTPResponse> responses = new List<OTPResponse>();
        List<Zentra_OTP_Session__c> sessionsToInsert = new List<Zentra_OTP_Session__c>();
        List<Integer> requestIndexMap = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            OTPRequest req = requests[i];
            OTPResponse resp = new OTPResponse();

            // Validate inputs
            if (String.isBlank(req.phoneNumber) || req.accountId == null) {
                resp.success = false;
                resp.message = 'Phone number and Account Id are required.';
                responses.add(resp);
                continue;
            }

            // Check for active lockout
            if (hasActiveLockout(req.accountId)) {
                resp.success = false;
                resp.message = 'Account is temporarily locked due to too many failed attempts. Please try again after 30 minutes.';
                responses.add(resp);
                continue;
            }

            // Expire any existing active sessions for this customer
            expireActiveSessions(req.accountId);

            String otpCode = generateOTP();
            DateTime expiresAt = DateTime.now().addMinutes(OTP_EXPIRY_MINUTES);
            String channel = String.isNotBlank(req.channel) ? req.channel : 'WhatsApp';

            Zentra_OTP_Session__c session = new Zentra_OTP_Session__c(
                Customer__c = req.accountId,
                OTP_Code__c = otpCode,
                Phone_Number__c = req.phoneNumber,
                Channel__c = channel,
                Status__c = 'Sent',
                Expires_At__c = expiresAt,
                Attempt_Count__c = 0
            );

            sessionsToInsert.add(session);
            requestIndexMap.add(i);

            resp.success = true;
            resp.expiresAt = expiresAt;
            responses.add(resp);
        }

        // Bulk insert sessions
        if (!sessionsToInsert.isEmpty()) {
            insert sessionsToInsert;

            // Collect account Ids for contact email lookup
            Set<Id> accountIds = new Set<Id>();
            for (Integer j = 0; j < sessionsToInsert.size(); j++) {
                Integer originalIndex = requestIndexMap[j];
                accountIds.add(requests[originalIndex].accountId);
            }

            // Query Contacts related to each Account to get their email
            Map<Id, Contact> contactByAccountMap = new Map<Id, Contact>();
            for (Contact c : [SELECT Id, Email, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Email != null ORDER BY CreatedDate ASC]) {
                if (!contactByAccountMap.containsKey(c.AccountId)) {
                    contactByAccountMap.put(c.AccountId, c);
                }
            }

            // Query Org-Wide Email Address for sending
            Id orgWideEmailId = getOrgWideEmailAddressId();

            // Map back the IDs, send SMS and email
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            for (Integer j = 0; j < sessionsToInsert.size(); j++) {
                Zentra_OTP_Session__c insertedSession = sessionsToInsert[j];
                Integer originalIndex = requestIndexMap[j];
                OTPResponse resp = responses[originalIndex];
                resp.otpSessionId = insertedSession.Id;

                OTPRequest req = requests[originalIndex];
                // Send OTP via SMS (mock in hackathon)
                sendSMS(req.phoneNumber, insertedSession.OTP_Code__c);

                // Build and queue OTP email using Contact email
                Contact con = contactByAccountMap.get(req.accountId);
                if (con != null && String.isNotBlank(con.Email)) {
                    emails.add(buildOTPEmail(con, insertedSession.OTP_Code__c, orgWideEmailId, req.purpose));
                }

                resp.message = 'OTP generated successfully. Valid for ' + OTP_EXPIRY_MINUTES + ' minutes.';
            }

            // Bulk send emails — fire and forget, do not fail the OTP flow
            if (!emails.isEmpty()) {
                try {
                    List<Messaging.SendEmailResult> emailResults = Messaging.sendEmail(emails, false);
                    // Log each OTP email to Zentra_Email_Log__c
                    for (Integer k = 0; k < emails.size(); k++) {
                        Messaging.SingleEmailMessage sentMsg = emails[k];
                        String toAddr = sentMsg.getToAddresses() != null && !sentMsg.getToAddresses().isEmpty() ? sentMsg.getToAddresses()[0] : null;
                        Boolean ok = emailResults != null && k < emailResults.size() && emailResults[k].isSuccess();
                        String errMsg = null;
                        if (!ok && emailResults != null && k < emailResults.size()) {
                            for (Messaging.SendEmailError err : emailResults[k].getErrors()) {
                                errMsg = (errMsg == null ? '' : errMsg) + err.getStatusCode() + ': ' + err.getMessage() + '; ';
                            }
                        }
                        // Find account Id for this email
                        Id acctId = null;
                        if (k < sessionsToInsert.size()) {
                            Integer origIdx = requestIndexMap[k];
                            acctId = requests[origIdx].accountId;
                        }
                        String logPurpose = (k < sessionsToInsert.size() && String.isNotBlank(requests[requestIndexMap[k]].purpose)) ? requests[requestIndexMap[k]].purpose : 'OTP';
                        ZentraEmailService.logEmailAudit(acctId, logPurpose, toAddr, sentMsg.getSubject(), ok ? 'Sent' : 'Failed', errMsg);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'OTP email send failed: ' + e.getMessage());
                }
            }
        }

        return responses;
    }

    /**
     * @description Generates a random 6-digit OTP. In hackathon mode, returns mock OTP.
     * @return 6-digit OTP string
     */
    @TestVisible
    private static String generateOTP() {
        // Hackathon: return mock OTP for predictable testing
        if (Test.isRunningTest()) {
            return MOCK_OTP;
        }
        Integer otp = (Integer) Math.floor(Math.random() * 900000) + 100000;
        return String.valueOf(otp);
    }

    /**
     * @description Checks if the customer account has an active lockout (Locked session within last 30 minutes).
     * @param accountId The Account Id to check
     * @return true if locked out
     */
    @TestVisible
    private static Boolean hasActiveLockout(Id accountId) {
        DateTime lockoutThreshold = DateTime.now().addMinutes(-30);
        List<Zentra_OTP_Session__c> lockedSessions = [
            SELECT Id
            FROM Zentra_OTP_Session__c
            WHERE Customer__c = :accountId
              AND Status__c = 'Locked'
              AND CreatedDate >= :lockoutThreshold
            LIMIT 1
        ];
        return !lockedSessions.isEmpty();
    }

    /**
     * @description Expires any active (Sent) OTP sessions for a customer before creating a new one.
     * @param accountId The Account Id whose sessions should be expired
     */
    private static void expireActiveSessions(Id accountId) {
        List<Zentra_OTP_Session__c> activeSessions = [
            SELECT Id, Status__c
            FROM Zentra_OTP_Session__c
            WHERE Customer__c = :accountId
              AND Status__c = 'Sent'
            FOR UPDATE
        ];

        for (Zentra_OTP_Session__c session : activeSessions) {
            session.Status__c = 'Expired';
        }

        if (!activeSessions.isEmpty()) {
            update activeSessions;
        }
    }

    /**
     * @description Masks a phone number for display, showing only last 4 digits.
     * @param phone Full phone number
     * @return Masked phone string
     */
    @TestVisible
    private static String maskPhoneNumber(String phone) {
        if (String.isBlank(phone) || phone.length() < 4) {
            return '****';
        }
        return 'XXXX-' + phone.substring(phone.length() - 4);
    }

    /**
     * @description Sends OTP via SMS gateway. Hackathon: logs instead of real SMS.
     * @param phoneNumber Target phone number
     * @param otpCode The OTP code to send
     */
    @TestVisible
    private static void sendSMS(String phoneNumber, String otpCode) {
        // Hackathon: Mock SMS — in production, replace with Named Credential callout to SMS gateway
        System.debug('=== OTP SMS (MOCK) === Phone: ' + maskPhoneNumber(phoneNumber) + ' | OTP sent successfully.');
    }

    /**
     * @description Returns the Id of the first available Org-Wide Email Address for sending.
     * @return OrgWideEmailAddress Id, or null if none configured
     */
    @TestVisible
    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
        if (owea.isEmpty()) {
            owea = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        }
        return owea.isEmpty() ? null : owea[0].Id;
    }

    /**
     * @description Builds a branded OTP email using Messaging.SingleEmailMessage.
     * @param con The Contact record with Email and FirstName
     * @param otpCode The OTP code to include in the email
     * @param orgWideEmailId Org-Wide Email Address Id for sender (can be null)
     * @return Configured SingleEmailMessage ready to send
     */
    @TestVisible
    private static Messaging.SingleEmailMessage buildOTPEmail(Contact con, String otpCode, Id orgWideEmailId) {
        return buildOTPEmail(con, otpCode, orgWideEmailId, null);
    }

    @TestVisible
    private static Messaging.SingleEmailMessage buildOTPEmail(Contact con, String otpCode, Id orgWideEmailId, String purpose) {
        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Customer';

        // Resolve config from Zentra_Email_Config__mdt (OTP record + Master for branding)
        String brand  = '#1a237e';
        String bank   = 'Zentra Bank';
        String heading = 'Your OTP Verification Code';
        String intro   = 'You have requested a One-Time Password (OTP) to log in to <strong>' + bank + ' Mobile Services</strong>. '
            + 'Please use the following OTP to complete your authentication:';
        String subjectLine = bank + ' - Your Login OTP for Mobile Services';

        // Try loading from metadata — gracefully fall back to defaults
        try {
            Zentra_Email_Config__mdt master = Zentra_Email_Config__mdt.getInstance('Master');
            if (master != null) {
                if (String.isNotBlank(master.Brand_Color__c)) { brand = master.Brand_Color__c; }
                if (String.isNotBlank(master.Bank_Name__c))   { bank  = master.Bank_Name__c; }
            }
            String configName = String.isNotBlank(purpose) ? purpose : 'OTP';
            Zentra_Email_Config__mdt otpCfg = Zentra_Email_Config__mdt.getInstance(configName);
            if (otpCfg == null) {
                otpCfg = Zentra_Email_Config__mdt.getInstance('OTP');
            }
            if (otpCfg != null) {
                if (String.isNotBlank(otpCfg.Heading__c))          { heading = otpCfg.Heading__c; }
                if (String.isNotBlank(otpCfg.Intro_Text__c))       { intro = otpCfg.Intro_Text__c; }
                if (String.isNotBlank(otpCfg.Subject_Template__c)) {
                    subjectLine = String.format(otpCfg.Subject_Template__c, new List<String>{ bank });
                }
            }
        } catch (Exception e) {
            // Metadata not deployed yet — use defaults silently
        }

        String htmlBody = '<html><body style="margin:0;padding:0;background-color:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">'
            + '<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f6f9;padding:30px 0;"><tr><td align="center">'
            + '<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">'
            + '<tr><td style="background:linear-gradient(135deg,' + brand + ',#283593);padding:30px 40px;text-align:center;">'
            + '<h1 style="color:#ffffff;margin:0;font-size:24px;font-weight:700;letter-spacing:1px;">' + bank.toUpperCase() + '</h1>'
            + '<p style="color:#9fa8da;margin:5px 0 0 0;font-size:13px;letter-spacing:2px;">TRUSTED &amp; SECURE BANKING</p></td></tr>'
            + '<tr><td style="padding:40px;">'
            + '<p style="color:#333;font-size:16px;margin:0 0 10px 0;">Dear ' + firstName + ',</p>'
            + '<p style="color:#555;font-size:14px;line-height:1.6;margin:0 0 25px 0;">' + intro + '</p>'
            + '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:15px 0;">'
            + '<table cellpadding="0" cellspacing="0" style="background-color:#e8eaf6;border:2px dashed #3949ab;border-radius:8px;padding:20px 50px;">'
            + '<tr><td style="text-align:center;">'
            + '<p style="color:#666;font-size:12px;margin:0 0 8px 0;text-transform:uppercase;letter-spacing:2px;">' + heading + '</p>'
            + '<p style="color:' + brand + ';font-size:36px;font-weight:700;margin:0;letter-spacing:8px;font-family:Courier New,monospace;">' + otpCode + '</p>'
            + '</td></tr></table></td></tr></table>'
            + '<table width="100%" cellpadding="0" cellspacing="0" style="margin-top:25px;background-color:#fff8e1;border-left:4px solid #f9a825;border-radius:4px;padding:15px;">'
            + '<tr><td><p style="color:#e65100;font-size:13px;margin:0;"><strong>Important:</strong></p>'
            + '<ul style="color:#555;font-size:13px;margin:8px 0 0 0;padding-left:18px;">'
            + '<li>This OTP is valid for <strong>' + OTP_EXPIRY_MINUTES + ' minutes</strong> only.</li>'
            + '<li>Do not share this OTP with anyone.</li>'
            + '<li>' + bank + ' will never ask for your OTP via call or message.</li></ul></td></tr></table>'
            + '</td></tr>'
            + '<tr><td style="background-color:#f5f5f5;padding:20px 40px;text-align:center;">'
            + '<p style="color:#999;font-size:12px;margin:0;">This is an automated message from ' + bank + '. Please do not reply.</p>'
            + '<p style="color:#999;font-size:11px;margin:5px 0 0 0;">&copy; 2026 ' + bank + '. All rights reserved.</p>'
            + '</td></tr></table></td></tr></table></body></html>';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ con.Email });
        email.setSubject(subjectLine);
        email.setHtmlBody(htmlBody);
        email.setSaveAsActivity(false);
        if (orgWideEmailId != null) {
            email.setOrgWideEmailAddressId(orgWideEmailId);
        }
        return email;
    }

}