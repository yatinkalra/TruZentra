// ============================================================
// DEBUG: View Recent Error Logs (all customers)
// Run: sf apex run --file scripts/debug-error-logs.apex --target-org AF
// ============================================================
// CONFIGURE:
Integer LOG_COUNT = 20;  // Number of recent errors to show

System.debug('=== Last ' + LOG_COUNT + ' Zentra Error Logs ===');
for (Zentra_Error_Log__c el : [
    SELECT Name, Source_Class__c, Method__c, Error_Message__c, Stack_Trace__c,
           Customer__c, Customer__r.Name, CreatedDate
    FROM Zentra_Error_Log__c
    ORDER BY CreatedDate DESC LIMIT :LOG_COUNT
]) {
    System.debug('────────────────────────────');
    System.debug('Time:    ' + el.CreatedDate);
    System.debug('Class:   ' + el.Source_Class__c + '.' + el.Method__c);
    System.debug('Account: ' + (el.Customer__r != null ? el.Customer__r.Name : 'N/A'));
    System.debug('Error:   ' + el.Error_Message__c);
    if (String.isNotBlank(el.Stack_Trace__c)) {
        System.debug('Stack:   ' + el.Stack_Trace__c.left(200));
    }
}

// --- Summary by class ---
System.debug('\n=== Error Count by Class (last 7 days) ===');
for (AggregateResult ar : [
    SELECT Source_Class__c cls, COUNT(Id) cnt
    FROM Zentra_Error_Log__c
    WHERE CreatedDate = LAST_N_DAYS:7
    GROUP BY Source_Class__c
    ORDER BY COUNT(Id) DESC
]) {
    System.debug(ar.get('cls') + ': ' + ar.get('cnt'));
}
