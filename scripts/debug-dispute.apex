// ============================================================
// DEBUG: Dispute Creation + Status Check
// Run: sf apex run --file scripts/debug-dispute.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Customer phone

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- Find a transaction to dispute ---
List<FinServ__FinancialAccountTransaction__c> txns = [
    SELECT Id, FinServ__Amount__c, FinServ__Description__c,
           FinServ__TransactionDate__c, FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c
    FROM FinServ__FinancialAccountTransaction__c
    WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :acctId
    ORDER BY FinServ__TransactionDate__c DESC LIMIT 5
];
System.debug('\n=== Recent Undisputed Transactions ===');
for (Integer i = 0; i < txns.size(); i++) {
    System.debug((i+1) + '. ' + txns[i].FinServ__Description__c + ' | Rs.' + txns[i].FinServ__Amount__c
        + ' | ' + txns[i].FinServ__TransactionDate__c + ' | ' + txns[i].Id);
}

if (txns.isEmpty()) { System.debug('No undisputed transactions found.'); return; }

// --- Create Dispute ---
System.debug('\n=== Creating Dispute for txn #1 ===');
ZentraDisputeService.DisputeRequest dreq = new ZentraDisputeService.DisputeRequest();
dreq.customerId = acctId;
dreq.amount = txns[0].FinServ__Amount__c;
dreq.merchantHint = txns[0].FinServ__Description__c;
dreq.reason = 'Not recognized';

List<ZentraDisputeService.DisputeResult> dres = ZentraDisputeService.createDispute(
    new List<ZentraDisputeService.DisputeRequest>{ dreq }
);
System.debug('Success:     ' + dres[0].success);
System.debug('Case Number: ' + dres[0].caseNumber);
System.debug('Message:     ' + dres[0].message);

// --- Check Dispute Status ---
System.debug('\n=== Dispute Status ===');
ZentraDisputeStatusService.DisputeStatusRequest sreq = new ZentraDisputeStatusService.DisputeStatusRequest();
sreq.customerId = acctId;

List<ZentraDisputeStatusService.DisputeStatusResult> sres = ZentraDisputeStatusService.getDisputeStatus(
    new List<ZentraDisputeStatusService.DisputeStatusRequest>{ sreq }
);
System.debug('Success: ' + sres[0].success);
System.debug('Summary:\n' + sres[0].statusSummary);
