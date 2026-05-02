/**
 * @description Test class for ZentraOTPService and ZentraOTPVerifyService invocable methods.
 *              Covers OTP generation, sending, verification, expiry, lockout, and edge cases.
 * @author      BlueForce Team
 * @date        2026-04-10
 */
@IsTest
private class ZentraOTPServiceTest {

    private static final String TEST_PHONE = '+919876543210';


    @TestSetup
    static void setupTestData() {
        Id personAccountRTId = getPersonAccountRecordTypeId();

        if (personAccountRTId != null) {
            Account testAccount = new Account(
                LastName = 'Sharma',
                FirstName = 'Rajesh',
                Phone = TEST_PHONE,
                PersonEmail = 'rajesh.sharma@test.com',
                RecordTypeId = personAccountRTId
            );
            insert testAccount;
        } else {
            Account testAccount = new Account(
                Name = 'Sharma',
                Phone = TEST_PHONE
            );
            insert testAccount;

            Contact testContact = new Contact(
                LastName = 'Sharma',
                FirstName = 'Rajesh',
                Email = 'rajesh.sharma@test.com',
                AccountId = testAccount.Id
            );
            insert testContact;
        }
    }

    // ─── ZentraOTPService Tests ────────────────────────────────────────

    @IsTest
    static void testSendOTP_Success() {
        Account acct = getTestAccount();

        ZentraOTPService.OTPRequest req = new ZentraOTPService.OTPRequest();
        req.phoneNumber = TEST_PHONE;
        req.accountId = acct.Id;
        req.channel = 'WhatsApp';

        Test.startTest();
        List<ZentraOTPService.OTPResponse> responses = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        ZentraOTPService.OTPResponse resp = responses[0];
        System.assertEquals(true, resp.success, 'OTP should be sent successfully');
        System.assertNotEquals(null, resp.otpSessionId, 'OTP Session Id should be populated');
        System.assertNotEquals(null, resp.expiresAt, 'Expiry should be set');
        System.assert(resp.message.contains('OTP generated successfully'), 'Message should confirm OTP generated');

        // Verify Zentra_OTP_Session__c record
        Zentra_OTP_Session__c session = [
            SELECT Id, Status__c, OTP_Code__c, Channel__c, Attempt_Count__c, Customer__c
            FROM Zentra_OTP_Session__c
            WHERE Id = :resp.otpSessionId
        ];
        System.assertEquals('Sent', session.Status__c, 'Status should be Sent');
        System.assertEquals('123456', session.OTP_Code__c, 'Mock OTP should be 123456');
        System.assertEquals('WhatsApp', session.Channel__c, 'Channel should be WhatsApp');
        System.assertEquals(0, session.Attempt_Count__c, 'Attempt count should be 0');
        System.assertEquals(acct.Id, session.Customer__c, 'Customer should match');
    }

    @IsTest
    static void testSendOTP_DefaultChannel() {
        Account acct = getTestAccount();

        ZentraOTPService.OTPRequest req = new ZentraOTPService.OTPRequest();
        req.phoneNumber = TEST_PHONE;
        req.accountId = acct.Id;
        // channel intentionally left blank

        Test.startTest();
        List<ZentraOTPService.OTPResponse> responses = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, responses[0].success);

        Zentra_OTP_Session__c session = [
            SELECT Channel__c FROM Zentra_OTP_Session__c WHERE Id = :responses[0].otpSessionId
        ];
        System.assertEquals('WhatsApp', session.Channel__c, 'Default channel should be WhatsApp');
    }

    @IsTest
    static void testSendOTP_MissingInputs() {
        ZentraOTPService.OTPRequest req = new ZentraOTPService.OTPRequest();
        req.phoneNumber = '';
        req.accountId = null;

        Test.startTest();
        List<ZentraOTPService.OTPResponse> responses = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Should fail with missing inputs');
        System.assert(responses[0].message.contains('required'), 'Message should mention required fields');
    }

    @IsTest
    static void testSendOTP_ExpiresPreviousSession() {
        Account acct = getTestAccount();

        // Create a first OTP session
        ZentraOTPService.OTPRequest req1 = new ZentraOTPService.OTPRequest();
        req1.phoneNumber = TEST_PHONE;
        req1.accountId = acct.Id;

        Test.startTest();
        List<ZentraOTPService.OTPResponse> resp1 = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req1 }
        );

        Id firstSessionId = resp1[0].otpSessionId;

        // Send a second OTP — should expire the first
        ZentraOTPService.OTPRequest req2 = new ZentraOTPService.OTPRequest();
        req2.phoneNumber = TEST_PHONE;
        req2.accountId = acct.Id;

        List<ZentraOTPService.OTPResponse> resp2 = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req2 }
        );
        Test.stopTest();

        // First session should be expired
        Zentra_OTP_Session__c firstSession = [
            SELECT Status__c FROM Zentra_OTP_Session__c WHERE Id = :firstSessionId
        ];
        System.assertEquals('Expired', firstSession.Status__c, 'Previous session should be expired');

        // Second session should be active
        System.assertEquals(true, resp2[0].success, 'Second OTP should succeed');
    }

    @IsTest
    static void testSendOTP_LockedAccount() {
        Account acct = getTestAccount();

        // Create a locked session
        Zentra_OTP_Session__c lockedSession = new Zentra_OTP_Session__c(
            Customer__c = acct.Id,
            OTP_Code__c = '999999',
            Phone_Number__c = TEST_PHONE,
            Channel__c = 'WhatsApp',
            Status__c = 'Locked',
            Expires_At__c = DateTime.now().addMinutes(30),
            Attempt_Count__c = 3
        );
        insert lockedSession;

        ZentraOTPService.OTPRequest req = new ZentraOTPService.OTPRequest();
        req.phoneNumber = TEST_PHONE;
        req.accountId = acct.Id;

        Test.startTest();
        List<ZentraOTPService.OTPResponse> responses = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, responses[0].success, 'Should fail due to lockout');
        System.assert(responses[0].message.contains('locked'), 'Message should mention lockout');
    }

    // ─── ZentraOTPVerifyService Tests ──────────────────────────────────

    @IsTest
    static void testVerifyOTP_Success() {
        Account acct = getTestAccount();

        // Create OTP session first
        ZentraOTPService.OTPRequest sendReq = new ZentraOTPService.OTPRequest();
        sendReq.phoneNumber = TEST_PHONE;
        sendReq.accountId = acct.Id;

        List<ZentraOTPService.OTPResponse> sendResp = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ sendReq }
        );

        // Verify with correct OTP
        ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
        verifyReq.otpCode = '123456';
        verifyReq.accountId = acct.Id;
        verifyReq.otpSessionId = sendResp[0].otpSessionId;

        Test.startTest();
        List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
            new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
        );
        Test.stopTest();

        System.assertEquals(true, verifyResp[0].verified, 'OTP should be verified');
        System.assertNotEquals(null, verifyResp[0].sessionToken, 'Session token should be generated');
        System.assert(verifyResp[0].message.contains('verified successfully'), 'Message should confirm verification');

        // Check session record
        Zentra_OTP_Session__c session = [
            SELECT Status__c, Session_Token__c FROM Zentra_OTP_Session__c WHERE Id = :sendResp[0].otpSessionId
        ];
        System.assertEquals('Verified', session.Status__c, 'Status should be Verified');
        System.assertNotEquals(null, session.Session_Token__c, 'Session token should be stored');
    }

    @IsTest
    static void testVerifyOTP_WrongCode() {
        Account acct = getTestAccount();

        // Create OTP session
        ZentraOTPService.OTPRequest sendReq = new ZentraOTPService.OTPRequest();
        sendReq.phoneNumber = TEST_PHONE;
        sendReq.accountId = acct.Id;

        List<ZentraOTPService.OTPResponse> sendResp = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ sendReq }
        );

        // Verify with wrong OTP
        ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
        verifyReq.otpCode = '000000';
        verifyReq.accountId = acct.Id;
        verifyReq.otpSessionId = sendResp[0].otpSessionId;

        Test.startTest();
        List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
            new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
        );
        Test.stopTest();

        System.assertEquals(false, verifyResp[0].verified, 'Verification should fail');
        System.assertEquals(2, verifyResp[0].remainingAttempts, 'Should have 2 remaining attempts');
        System.assert(verifyResp[0].message.contains('Incorrect OTP'), 'Message should indicate wrong code');
    }

    @IsTest
    static void testVerifyOTP_Lockout() {
        Account acct = getTestAccount();

        // Create OTP session
        ZentraOTPService.OTPRequest sendReq = new ZentraOTPService.OTPRequest();
        sendReq.phoneNumber = TEST_PHONE;
        sendReq.accountId = acct.Id;

        List<ZentraOTPService.OTPResponse> sendResp = ZentraOTPService.sendOTP(
            new List<ZentraOTPService.OTPRequest>{ sendReq }
        );

        Test.startTest();

        // Fail 3 times
        for (Integer i = 0; i < 3; i++) {
            ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
            verifyReq.otpCode = '000000';
            verifyReq.accountId = acct.Id;

            List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
                new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
            );

            if (i < 2) {
                System.assertEquals(false, verifyResp[0].verified);
                System.assert(verifyResp[0].remainingAttempts > 0);
            } else {
                System.assertEquals(false, verifyResp[0].verified);
                System.assertEquals(0, verifyResp[0].remainingAttempts);
                System.assert(verifyResp[0].message.contains('locked'), 'Should indicate lockout');
            }
        }

        Test.stopTest();

        // Verify session is locked
        Zentra_OTP_Session__c session = [
            SELECT Status__c, Attempt_Count__c FROM Zentra_OTP_Session__c WHERE Id = :sendResp[0].otpSessionId
        ];
        System.assertEquals('Locked', session.Status__c, 'Session should be locked');
        System.assertEquals(3, session.Attempt_Count__c, 'Attempt count should be 3');
    }

    @IsTest
    static void testVerifyOTP_ExpiredSession() {
        Account acct = getTestAccount();

        // Create an already-expired OTP session
        Zentra_OTP_Session__c expiredSession = new Zentra_OTP_Session__c(
            Customer__c = acct.Id,
            OTP_Code__c = '123456',
            Phone_Number__c = TEST_PHONE,
            Channel__c = 'WhatsApp',
            Status__c = 'Sent',
            Expires_At__c = DateTime.now().addMinutes(-1),
            Attempt_Count__c = 0
        );
        insert expiredSession;

        ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
        verifyReq.otpCode = '123456';
        verifyReq.accountId = acct.Id;
        verifyReq.otpSessionId = expiredSession.Id;

        Test.startTest();
        List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
            new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
        );
        Test.stopTest();

        System.assertEquals(false, verifyResp[0].verified, 'Expired OTP should not verify');
        System.assert(verifyResp[0].message.contains('expired'), 'Message should mention expiry');
    }

    @IsTest
    static void testVerifyOTP_NoActiveSession() {
        Account acct = getTestAccount();

        ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
        verifyReq.otpCode = '123456';
        verifyReq.accountId = acct.Id;

        Test.startTest();
        List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
            new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
        );
        Test.stopTest();

        System.assertEquals(false, verifyResp[0].verified, 'Should fail with no active session');
        System.assert(verifyResp[0].message.contains('No active OTP session'), 'Message should say no active session');
    }

    @IsTest
    static void testVerifyOTP_MissingInputs() {
        ZentraOTPVerifyService.VerifyRequest verifyReq = new ZentraOTPVerifyService.VerifyRequest();
        verifyReq.otpCode = '';
        verifyReq.accountId = null;
        verifyReq.otpSessionId = null;

        Test.startTest();
        List<ZentraOTPVerifyService.VerifyResponse> verifyResp = ZentraOTPVerifyService.verifyOTP(
            new List<ZentraOTPVerifyService.VerifyRequest>{ verifyReq }
        );
        Test.stopTest();

        System.assertEquals(false, verifyResp[0].verified, 'Should fail with missing inputs');
    }

    @IsTest
    static void testMaskPhoneNumber() {
        System.assertEquals('XXXX-3210', ZentraOTPService.maskPhoneNumber('+919876543210'));
        System.assertEquals('****', ZentraOTPService.maskPhoneNumber(''));
        System.assertEquals('****', ZentraOTPService.maskPhoneNumber(null));
    }

    // ─── Helper Methods ──────────────────────────────────────────

    private static Account getTestAccount() {
        return [SELECT Id, Phone FROM Account WHERE Phone = :TEST_PHONE LIMIT 1];
    }

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = true AND IsActive = true
            LIMIT 1
        ];
        // Fallback if no Person Account RT exists (e.g., scratch org without FSC)
        if (rts.isEmpty()) {
            return null;
        }
        return rts[0].Id;
    }
}