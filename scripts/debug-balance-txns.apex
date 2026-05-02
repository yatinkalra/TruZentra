// ============================================================
// DEBUG: Balance Check + Transaction History
// Run: sf apex run --file scripts/debug-balance-txns.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Customer phone

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- 1. Check Balance ---
System.debug('\n=== Balance Check ===');
ZentraBalanceService.BalanceRequest balReq = new ZentraBalanceService.BalanceRequest();
balReq.customerId = acctId;

List<ZentraBalanceService.BalanceResult> balRes = ZentraBalanceService.getBalance(
    new List<ZentraBalanceService.BalanceRequest>{ balReq }
);
System.debug('Success: ' + balRes[0].success);
System.debug('Summary:\n' + balRes[0].balanceSummary);

// --- 2. Get Transactions ---
System.debug('\n=== Last 10 Transactions ===');
ZentraTransactionService.TransactionRequest txnReq = new ZentraTransactionService.TransactionRequest();
txnReq.customerId = acctId;
txnReq.transactionLimit = 10;

List<ZentraTransactionService.TransactionResult> txnRes = ZentraTransactionService.getTransactions(
    new List<ZentraTransactionService.TransactionRequest>{ txnReq }
);
System.debug('Success: ' + txnRes[0].success);
System.debug('Statement:\n' + txnRes[0].transactionSummary);
