// ============================================================
// DEBUG: Verify OTP (run AFTER debug-otp-flow.apex)
// Run: sf apex run --file scripts/debug-otp-verify.apex --target-org AF
// ============================================================
// CONFIGURE: Paste values from debug-otp-flow output
String OTP_SESSION_ID = 'PASTE_SESSION_ID_HERE';  // From Step 2 output
String OTP_CODE       = 'PASTE_OTP_CODE_HERE';    // From Step 3 output

System.debug('=== Verifying OTP ===');
System.debug('Session: ' + OTP_SESSION_ID);
System.debug('Code:    ' + OTP_CODE);

ZentraOTPVerifyService.VerifyRequest req = new ZentraOTPVerifyService.VerifyRequest();
req.otpSessionId = OTP_SESSION_ID;
req.otpCode = OTP_CODE;

List<ZentraOTPVerifyService.VerifyResponse> results = ZentraOTPVerifyService.verifyOTP(
    new List<ZentraOTPVerifyService.VerifyRequest>{ req }
);

ZentraOTPVerifyService.VerifyResponse res = results[0];
System.debug('Verified:    ' + res.verified);
System.debug('Customer Id: ' + res.customerId);
System.debug('Name:        ' + res.customerName);
System.debug('Message:     ' + res.message);
System.debug('Token:       ' + res.sessionToken);
System.debug('Remaining:   ' + res.remainingAttempts);
