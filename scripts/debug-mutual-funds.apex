// ============================================================
// DEBUG: Mutual Fund / SIP Holdings
// Run: sf apex run --file scripts/debug-mutual-funds.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Customer phone
Integer SIP_INDEX = 0;        // 0 = quick summary, 1+ = detail of specific SIP

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- Get MF Holdings ---
System.debug('\n=== Mutual Fund Holdings (index=' + SIP_INDEX + ') ===');
ZentraMutualFundService.MFRequest mfReq = new ZentraMutualFundService.MFRequest();
mfReq.customerId = acctId;
mfReq.sipIndex = SIP_INDEX;

List<ZentraMutualFundService.MFResult> mfRes = ZentraMutualFundService.getMutualFundHoldings(
    new List<ZentraMutualFundService.MFRequest>{ mfReq }
);
System.debug('Success: ' + mfRes[0].success);
System.debug('Summary:\n' + mfRes[0].outputMessage);

// --- Count SIPs by status ---
List<FinServ__FinancialHolding__c> sips = [SELECT Status__c FROM FinServ__FinancialHolding__c WHERE FinServ__PrimaryOwner__c = :acctId];
Map<String, Integer> statusCount = new Map<String, Integer>();
for (FinServ__FinancialHolding__c s : sips) {
    String st = s.Status__c != null ? s.Status__c : 'Unknown';
    statusCount.put(st, (statusCount.containsKey(st) ? statusCount.get(st) : 0) + 1);
}
System.debug('\n=== SIP Status Breakdown ===');
for (String st : statusCount.keySet()) {
    System.debug(st + ': ' + statusCount.get(st));
}
