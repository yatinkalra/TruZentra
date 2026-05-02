/**
 * @description Invocable Apex service to verify OTP codes submitted by customers.
 *              Designed to be called from Flows and Agentforce Actions.
 *              Validates OTP against Zentra_OTP_Session__c, handles attempt counting, lockout, and session token generation.
 * @author      BlueForce Team
 * @date        2026-04-10
 */
public without sharing class ZentraOTPVerifyService {

    private static final Integer MAX_ATTEMPTS = 3;

    /**
     * @description Input wrapper for the invocable method — used by Flow / Agentforce.
     */
    public class VerifyRequest {
        @InvocableVariable(label='OTP Code' description='The 6-digit OTP code entered by the customer' required=true)
        public String otpCode;

        @InvocableVariable(label='Account Id' description='Account record Id of the customer (optional if OTP Session Id is provided)' required=false)
        public Id accountId;

        @InvocableVariable(label='OTP Session Id' description='Optional: specific Zentra_OTP_Session__c Id to verify against' required=false)
        public Id otpSessionId;
    }

    /**
     * @description Output wrapper returned to Flow / Agentforce.
     */
    public class VerifyResponse {
        @InvocableVariable(label='Verified' description='Whether the OTP was successfully verified')
        public Boolean verified;

        @InvocableVariable(label='Message' description='User-facing response message')
        public String message;

        @InvocableVariable(label='Session Token' description='Session token for subsequent authenticated requests')
        public String sessionToken;

        @InvocableVariable(label='OTP Session Id' description='Id of the Zentra_OTP_Session__c record')
        public Id otpSessionId;

        @InvocableVariable(label='Remaining Attempts' description='Number of remaining verification attempts')
        public Integer remainingAttempts;

        @InvocableVariable(label='Customer Id' description='Account Id of the verified customer')
        public Id customerId;
    }

    /**
     * @description Verifies the OTP code against the most recent active Zentra_OTP_Session__c for the customer.
     *              Handles attempt counting, expiry checks, and lockout after max attempts.
     * @param requests List of VerifyRequest from Flow
     * @return List of VerifyResponse with verification result
     */
    @InvocableMethod(label='Verify OTP' description='Verifies a 6-digit OTP code against the active OTP session for the customer. Handles expiry and lockout.' category='Authentication')
    public static List<VerifyResponse> verifyOTP(List<VerifyRequest> requests) {
        List<VerifyResponse> responses = new List<VerifyResponse>();

        for (VerifyRequest req : requests) {
            VerifyResponse resp = new VerifyResponse();

            // Validate inputs
            if (String.isBlank(req.otpCode) || (req.accountId == null && req.otpSessionId == null)) {
                resp.verified = false;
                resp.message = 'OTP code and either Account Id or OTP Session Id are required.';
                resp.remainingAttempts = 0;
                responses.add(resp);
                continue;
            }
            req.otpCode = req.otpCode.trim();

            // Find the active OTP session
            Zentra_OTP_Session__c session = findActiveSession(req.accountId, req.otpSessionId);

            if (session == null) {
                resp.verified = false;
                resp.message = 'No active OTP session found. Please request a new OTP.';
                resp.remainingAttempts = 0;
                responses.add(resp);
                continue;
            }

            // Check if session has expired
            if (session.Expires_At__c < DateTime.now()) {
                session.Status__c = 'Expired';
                update session;
                resp.verified = false;
                resp.message = 'OTP has expired. Please request a new OTP.';
                resp.otpSessionId = session.Id;
                resp.remainingAttempts = 0;
                responses.add(resp);
                continue;
            }

            // Check if already locked
            if (session.Status__c == 'Locked') {
                resp.verified = false;
                resp.message = 'This OTP session is locked due to too many failed attempts. Please request a new OTP after 30 minutes.';
                resp.otpSessionId = session.Id;
                resp.remainingAttempts = 0;
                responses.add(resp);
                continue;
            }

            // Increment attempt count
            session.Attempt_Count__c = session.Attempt_Count__c + 1;

            // Verify OTP code
            if (session.OTP_Code__c == req.otpCode.trim()) {
                // Success
                session.Status__c = 'Verified';
                session.Session_Token__c = generateSessionToken();
                update session;

                resp.verified = true;
                resp.message = 'OTP verified successfully.';
                resp.sessionToken = session.Session_Token__c;
                resp.otpSessionId = session.Id;
                resp.remainingAttempts = MAX_ATTEMPTS - (Integer) session.Attempt_Count__c;
                // Look up Account by phone number stored on the OTP session
                String phone = session.Phone_Number__c;
                if (String.isNotBlank(phone)) {
                    List<Account> accts = [SELECT Id FROM Account WHERE Phone = :phone LIMIT 1];
                    if (!accts.isEmpty()) {
                        resp.customerId = accts[0].Id;
                        // Send MPIN login notification email
                        ZentraEmailService.sendMpinLoginEmail(accts[0].Id);
                    }
                }
            } else {
                // Failed attempt
                Integer attemptsUsed = (Integer) session.Attempt_Count__c;
                Integer remaining = MAX_ATTEMPTS - attemptsUsed;

                if (attemptsUsed >= MAX_ATTEMPTS) {
                    // Lock the session
                    session.Status__c = 'Locked';
                    update session;

                    resp.verified = false;
                    resp.message = 'Maximum attempts exceeded. Account is temporarily locked for 30 minutes.';
                    resp.otpSessionId = session.Id;
                    resp.remainingAttempts = 0;
                } else {
                    update session;

                    resp.verified = false;
                    resp.message = 'Incorrect OTP. ' + remaining + ' attempt(s) remaining.';
                    resp.otpSessionId = session.Id;
                    resp.remainingAttempts = remaining;
                }
            }

            responses.add(resp);
        }

        return responses;
    }

    /**
     * @description Finds the most recent active OTP session for the given customer.
     * @param accountId Customer Account Id
     * @param otpSessionId Optional specific session Id to find
     * @return The active Zentra_OTP_Session__c or null
     */
    @TestVisible
    private static Zentra_OTP_Session__c findActiveSession(Id accountId, Id otpSessionId) {
        String query = 'SELECT Id, OTP_Code__c, Status__c, Expires_At__c, Attempt_Count__c, Session_Token__c, Phone_Number__c '
                     + 'FROM Zentra_OTP_Session__c '
                     + 'WHERE Status__c = \'Sent\' ';

        if (otpSessionId != null) {
            query += 'AND Id = :otpSessionId ';
        }

        String acctPhone = null;
        if (accountId != null) {
            // Look up phone from Account to filter sessions
            List<Account> accts = [SELECT Phone FROM Account WHERE Id = :accountId LIMIT 1];
            if (!accts.isEmpty() && String.isNotBlank(accts[0].Phone)) {
                acctPhone = accts[0].Phone;
                query += 'AND Phone_Number__c = :acctPhone ';
            }
        }

        query += 'ORDER BY CreatedDate DESC LIMIT 1';

        List<Zentra_OTP_Session__c> sessions = Database.query(query);
        return sessions.isEmpty() ? null : sessions[0];
    }

    /**
     * @description Generates a UUID-like session token for authenticated session tracking.
     * @return A unique session token string
     */
    @TestVisible
    private static String generateSessionToken() {
        Blob b = Crypto.generateAesKey(128);
        return EncodingUtil.convertToHex(b);
    }
}