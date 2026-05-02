// ============================================================
// DEBUG: Send All Email Types
// Run: sf apex run --file scripts/debug-email-all.apex --target-org AF
// ============================================================
// CONFIGURE: Set the customer phone or account Id below
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Change to your test customer phone

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name, Phone FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account found for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- 1. Balance Summary ---
System.debug('\n--- Balance Summary Email ---');
Boolean bal = ZentraEmailService.sendBalanceSummaryEmail(acctId);
System.debug('Result: ' + (bal ? 'SENT' : 'FAILED'));

// --- 2. Transaction Summary ---
System.debug('\n--- Transaction Summary Email ---');
Boolean txn = ZentraEmailService.sendTransactionSummaryEmail(acctId);
System.debug('Result: ' + (txn ? 'SENT' : 'FAILED'));

// --- 3. Dispute Summary (via ZentraEmailSummaryService) ---
System.debug('\n--- Dispute Summary Email ---');
ZentraEmailSummaryService.EmailSummaryRequest dispReq = new ZentraEmailSummaryService.EmailSummaryRequest();
dispReq.customerId = String.valueOf(acctId);
dispReq.emailType = 'dispute';
List<ZentraEmailSummaryService.EmailSummaryResult> dispRes = ZentraEmailSummaryService.sendEmailSummary(
    new List<ZentraEmailSummaryService.EmailSummaryRequest>{ dispReq });
System.debug('Result: ' + (dispRes[0].success ? 'SENT' : 'FAILED') + ' - ' + dispRes[0].message);

// --- 4. Loan Summary (via ZentraEmailSummaryService) ---
System.debug('\n--- Loan Summary Email ---');
ZentraEmailSummaryService.EmailSummaryRequest loanReq = new ZentraEmailSummaryService.EmailSummaryRequest();
loanReq.customerId = String.valueOf(acctId);
loanReq.emailType = 'loan';
List<ZentraEmailSummaryService.EmailSummaryResult> loanRes = ZentraEmailSummaryService.sendEmailSummary(
    new List<ZentraEmailSummaryService.EmailSummaryRequest>{ loanReq });
System.debug('Result: ' + (loanRes[0].success ? 'SENT' : 'FAILED') + ' - ' + loanRes[0].message);

// --- 5. Recurring Payment Summary ---
System.debug('\n--- Recurring Payment Summary Email ---');
Boolean rec = ZentraEmailService.sendRecurringPaymentSummaryEmail(acctId);
System.debug('Result: ' + (rec ? 'SENT' : 'FAILED'));

// --- 6. Mutual Fund Summary ---
System.debug('\n--- Mutual Fund Summary Email ---');
Boolean mf = ZentraEmailService.sendMutualFundSummaryEmail(acctId);
System.debug('Result: ' + (mf ? 'SENT' : 'FAILED'));

System.debug('\n=== All email debug complete ===');
