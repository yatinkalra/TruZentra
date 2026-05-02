// ============================================================
// DEBUG: Recurring Payments (View + Stop)
// Run: sf apex run --file scripts/debug-recurring-payments.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';     // Customer phone
Integer STOP_INDEX = 0;          // Set > 0 to stop a specific payment (1-based index)

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- 1. List All Recurring Payments ---
System.debug('\n=== Recurring Payments ===');
ZentraRecurringPaymentService.RecurringPaymentRequest rpReq = new ZentraRecurringPaymentService.RecurringPaymentRequest();
rpReq.customerId = acctId;

List<ZentraRecurringPaymentService.RecurringPaymentResult> rpRes = ZentraRecurringPaymentService.getRecurringPayments(
    new List<ZentraRecurringPaymentService.RecurringPaymentRequest>{ rpReq }
);
System.debug('Success: ' + rpRes[0].success);
System.debug('Count:   ' + rpRes[0].paymentCount);
System.debug('Summary:\n' + rpRes[0].summary);

// --- 2. Stop a Payment (optional) ---
if (STOP_INDEX > 0) {
    System.debug('\n=== Stopping Payment #' + STOP_INDEX + ' ===');
    ZentraStopRecurringPaymentService.StopPaymentRequest spReq = new ZentraStopRecurringPaymentService.StopPaymentRequest();
    spReq.customerId = acctId;
    spReq.paymentIndex = STOP_INDEX;

    List<ZentraStopRecurringPaymentService.StopPaymentResult> spRes = ZentraStopRecurringPaymentService.stopRecurringPayment(
        new List<ZentraStopRecurringPaymentService.StopPaymentRequest>{ spReq }
    );
    System.debug('Success: ' + spRes[0].success);
    System.debug('Message: ' + spRes[0].message);
}
