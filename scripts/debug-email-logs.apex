// ============================================================
// DEBUG: View Recent Email Audit Logs
// Run: sf apex run --file scripts/debug-email-logs.apex --target-org AF
// ============================================================
// CONFIGURE:
Integer LOG_COUNT = 20;  // Number of recent email logs to show

System.debug('=== Last ' + LOG_COUNT + ' Zentra Email Logs ===');
for (Zentra_Email_Log__c el : [
    SELECT Name, Email_Type__c, Recipient_Email__c, Subject__c, Status__c,
           Error_Message__c, Customer__r.Name, CreatedDate
    FROM Zentra_Email_Log__c
    ORDER BY CreatedDate DESC LIMIT :LOG_COUNT
]) {
    System.debug('────────────────────────────');
    System.debug('Time:    ' + el.CreatedDate);
    System.debug('Type:    ' + el.Email_Type__c);
    System.debug('To:      ' + el.Recipient_Email__c);
    System.debug('Subject: ' + el.Subject__c);
    System.debug('Status:  ' + el.Status__c);
    System.debug('Account: ' + (el.Customer__r != null ? el.Customer__r.Name : 'N/A'));
    if (String.isNotBlank(el.Error_Message__c)) {
        System.debug('Error:   ' + el.Error_Message__c);
    }
}

// --- Summary by type ---
System.debug('\n=== Email Count by Type (last 7 days) ===');
for (AggregateResult ar : [
    SELECT Email_Type__c typ, Status__c st, COUNT(Id) cnt
    FROM Zentra_Email_Log__c
    WHERE CreatedDate = LAST_N_DAYS:7
    GROUP BY Email_Type__c, Status__c
    ORDER BY Email_Type__c, Status__c
]) {
    System.debug(ar.get('typ') + ' [' + ar.get('st') + ']: ' + ar.get('cnt'));
}
