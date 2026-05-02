// ============================================================
// DEBUG: OTP Send + Verify Flow (end-to-end)
// Run: sf apex run --file scripts/debug-otp-flow.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Customer phone number

// --- 1. Account Lookup ---
System.debug('=== Step 1: Account Lookup ===');
ZentraAccountLookupService.LookupRequest lookupReq = new ZentraAccountLookupService.LookupRequest();
lookupReq.phoneNumber = PHONE;
List<ZentraAccountLookupService.LookupResponse> lookupRes = ZentraAccountLookupService.findAccount(
    new List<ZentraAccountLookupService.LookupRequest>{ lookupReq }
);
System.debug('Found:      ' + lookupRes[0].accountFound);
System.debug('Account Id: ' + lookupRes[0].accountId);
System.debug('Name:       ' + lookupRes[0].accountName);
System.debug('Normalized: ' + lookupRes[0].normalizedPhone);
System.debug('Message:    ' + lookupRes[0].message);

if (!lookupRes[0].accountFound) { System.debug('STOP: No account found.'); return; }

// --- 2. Send OTP ---
System.debug('\n=== Step 2: Send OTP ===');
ZentraOTPService.OTPRequest otpReq = new ZentraOTPService.OTPRequest();
otpReq.phoneNumber = lookupRes[0].normalizedPhone;
otpReq.accountId = lookupRes[0].accountId;
otpReq.channel = 'WhatsApp';

List<ZentraOTPService.OTPResponse> otpRes = ZentraOTPService.sendOTP(
    new List<ZentraOTPService.OTPRequest>{ otpReq }
);
System.debug('Success:    ' + otpRes[0].success);
System.debug('Session Id: ' + otpRes[0].otpSessionId);
System.debug('Expires:    ' + otpRes[0].expiresAt);
System.debug('Message:    ' + otpRes[0].message);

// --- 3. Retrieve OTP code (debug only!) ---
if (otpRes[0].otpSessionId != null) {
    Zentra_OTP_Session__c sess = [SELECT OTP_Code__c, Phone_Number__c, Status__c
        FROM Zentra_OTP_Session__c WHERE Id = :otpRes[0].otpSessionId];
    System.debug('\n=== OTP Session Record ===');
    System.debug('OTP Code:   ' + sess.OTP_Code__c);
    System.debug('Phone:      ' + sess.Phone_Number__c);
    System.debug('Status:     ' + sess.Status__c);
    System.debug('\n>> Use OTP code ' + sess.OTP_Code__c + ' with session ' + otpRes[0].otpSessionId + ' to verify');
}
