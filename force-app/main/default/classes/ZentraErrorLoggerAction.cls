/**
 * ZentraErrorLoggerAction
 * @description Invocable action wrapper for ZentraErrorLogger so Flows can log errors.
 * @developer   BlueForce Team
 * @date        2026-04-17
 */
public without sharing class ZentraErrorLoggerAction {

    @InvocableMethod(label='Log Error' description='Logs an error to Zentra_Error_Log__c. Use in Flow fault paths.' category='Error Logging')
    public static void logError(List<ErrorLogRequest> requests) {
        for (ErrorLogRequest req : requests) {
            ZentraErrorLogger.log(
                req.sourceClass,
                req.method,
                req.errorMessage,
                req.stackTrace,
                req.severity != null ? req.severity : 'Error',
                req.customerId != null ? Id.valueOf(req.customerId) : null
            );
        }
    }

    public class ErrorLogRequest {
        @InvocableVariable(label='Source Class' description='Flow or class name' required=true)
        public String sourceClass;

        @InvocableVariable(label='Method' description='Method or action name' required=false)
        public String method;

        @InvocableVariable(label='Error Message' description='Error message text' required=true)
        public String errorMessage;

        @InvocableVariable(label='Stack Trace' description='Stack trace if available' required=false)
        public String stackTrace;

        @InvocableVariable(label='Severity' description='Error, Warning, or Info' required=false)
        public String severity;

        @InvocableVariable(label='Customer Id' description='Account Id if available' required=false)
        public String customerId;
    }
}