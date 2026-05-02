/**
 * ZentraErrorLogger
 * @description Utility class to log errors to Zentra_Error_Log__c.
 *              Call from any Zentra service catch block.
 * @developer   BlueForce Team
 * @date        2026-04-17
 */
public without sharing class ZentraErrorLogger {

    public static void log(String sourceClass, String method, Exception e, Id customerId) {
        log(sourceClass, method, e.getMessage(), e.getStackTraceString(), 'Error', customerId);
    }

    public static void log(String sourceClass, String method, String message, String stackTrace, String severity, Id customerId) {
        try {
            Zentra_Error_Log__c errLog = new Zentra_Error_Log__c(
                Source_Class__c = sourceClass,
                Method__c = method,
                Error_Message__c = message,
                Stack_Trace__c = stackTrace,
                Severity__c = severity,
                Customer__c = customerId
            );
            insert errLog;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ZentraErrorLogger: Failed to insert error log — ' + ex.getMessage());
        }
    }

    public static void log(String sourceClass, String method, Exception e) {
        log(sourceClass, method, e, null);
    }

    public static void log(String sourceClass, String method, String message) {
        log(sourceClass, method, message, null, 'Error', null);
    }
}