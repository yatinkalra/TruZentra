// ============================================================
// DEBUG: New Account Opening Request
// Run: sf apex run --file scripts/debug-new-account.apex --target-org AF
// ============================================================
// CONFIGURE:
String PROSPECT_NAME  = 'Test Prospect';
String PROSPECT_EMAIL = 'test@example.com';
String PROSPECT_PHONE = '9999999999';

System.debug('=== New Account Opening Request ===');
System.debug('Name:  ' + PROSPECT_NAME);
System.debug('Email: ' + PROSPECT_EMAIL);
System.debug('Phone: ' + PROSPECT_PHONE);

ZentraNewAccountService.NewAccountRequest req = new ZentraNewAccountService.NewAccountRequest();
req.customerName = PROSPECT_NAME;
req.customerEmail = PROSPECT_EMAIL;
req.phoneNumber = PROSPECT_PHONE;

List<ZentraNewAccountService.NewAccountResult> results = ZentraNewAccountService.requestNewAccount(
    new List<ZentraNewAccountService.NewAccountRequest>{ req }
);

ZentraNewAccountService.NewAccountResult res = results[0];
System.debug('Success:     ' + res.success);
System.debug('Case Number: ' + res.caseNumber);
System.debug('RM Callback: ' + res.rmCallbackTime);
System.debug('Message:     ' + res.message);
