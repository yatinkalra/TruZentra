/**
 * ZentraStopRecurringPaymentService
 * @description Invocable Apex service to stop (cancel) an active recurring payment
 *              (standing instruction) for an authenticated customer. The customer
 *              selects a payment by its 1-based index from the quick summary list.
 *              On successful cancellation the service sends a confirmation email
 *              using the CMDT-driven ZentraEmailService.
 *              Designed to be called from Flows and Agentforce Actions.
 * @developer   BlueForce Team
 * @date        2026-04-20
 */
public without sharing class ZentraStopRecurringPaymentService {

    public class StopPaymentRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='Payment Index' description='1-based index of the active payment to stop (from the quick summary list)' required=true)
        public Integer paymentIndex;

        @InvocableVariable(label='Language' description='Language code: hi for Hindi, en for English. Defaults to en.' required=false)
        public String language;
    }

    public class StopPaymentResult {
        @InvocableVariable(label='Success' description='Whether the payment was successfully stopped')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-facing status message')
        public String message;
    }

    @InvocableMethod(label='Stop Recurring Payment'
        description='Stops (cancels) an active recurring payment by its index. Sends a cancellation confirmation email.'
        category='Account Management')
    public static List<StopPaymentResult> stopRecurringPayment(List<StopPaymentRequest> requests) {
        List<StopPaymentResult> results = new List<StopPaymentResult>();

        for (StopPaymentRequest req : requests) {
            StopPaymentResult r = new StopPaymentResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer Id is required.';
                    results.add(r);
                    continue;
                }
                Integer idx = (req.paymentIndex != null && req.paymentIndex > 0) ? req.paymentIndex : 0;
                if (idx == 0) {
                    r.success = false;
                    r.message = 'Please specify which payment to stop by providing its number from the list.';
                    results.add(r);
                    continue;
                }

                String lang = String.isNotBlank(req.language) ? req.language.toLowerCase().trim() : 'en';
                Boolean isHindi = (lang == 'hi');

                // Query only active payments in the same order as the quick summary
                List<Zentra_Recurring_Payment__c> payments = [
                    SELECT Id, Name, Payee_Name__c, Amount__c, Frequency__c, Status__c,
                           Next_Payment_Date__c, Source_Account__r.Name
                    FROM Zentra_Recurring_Payment__c
                    WHERE Customer__c = :req.customerId
                      AND Status__c = 'Active'
                    ORDER BY Next_Payment_Date__c ASC NULLS LAST, Start_Date__c ASC
                    LIMIT 50
                ];

                if (payments.isEmpty()) {
                    r.success = false;
                    r.message = isHindi
                        ? 'आपके खाते पर कोई सक्रिय स्थायी निर्देश नहीं मिला।'
                        : 'No active recurring payments found on your account.';
                    results.add(r);
                    continue;
                }

                if (idx > payments.size()) {
                    r.success = false;
                    r.message = isHindi
                        ? 'अमान्य क्रमांक। कृपया 1 से ' + payments.size() + ' के बीच कोई संख्या चुनें।'
                        : 'Invalid number. Please pick a number between 1 and ' + payments.size() + '.';
                    results.add(r);
                    continue;
                }

                // Cancel the selected payment
                Zentra_Recurring_Payment__c payment = payments.get(idx - 1);
                payment.Status__c = 'Cancelled';
                update payment;

                // Build confirmation message
                String payee = payment.Payee_Name__c != null ? payment.Payee_Name__c : '—';
                String amount = payment.Amount__c != null ? '₹' + formatCurrency(payment.Amount__c) : '—';

                // Send cancellation email (best-effort, don't fail the whole operation)
                try {
                    ZentraEmailService.sendRecurringPaymentCancelledEmail(
                        req.customerId, payee, payment.Amount__c, payment.Frequency__c, payment.Name
                    );
                } catch (Exception emailEx) {
                    System.debug(LoggingLevel.WARN, 'ZentraStopRecurringPaymentService: Cancellation email failed — ' + emailEx.getMessage());
                }

                r.success = true;
                if (isHindi) {
                    r.message = '✅ *स्थायी निर्देश रद्द किया गया*\n\n'
                        + '📌 *प्राप्तकर्ता:* ' + payee + '\n'
                        + '💰 *राशि:* ' + amount + '\n'
                        + '🔢 *संदर्भ:* ' + payment.Name + '\n\n'
                        + 'यह भुगतान अब रोक दिया गया है और आगे कोई राशि नहीं काटी जाएगी। '
                        + 'एक पुष्टि ईमेल आपके पंजीकृत ईमेल पर भेजी गई है।';
                } else {
                    r.message = '✅ *Recurring Payment Cancelled*\n\n'
                        + '📌 *Payee:* ' + payee + '\n'
                        + '💰 *Amount:* ' + amount + '\n'
                        + '🔢 *Reference:* ' + payment.Name + '\n\n'
                        + 'This standing instruction has been stopped. No further debits will be made. '
                        + 'A confirmation email has been sent to your registered email address.';
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraStopRecurringPaymentService', 'stopRecurringPayment', e,
                    req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Something went wrong while stopping the payment. Please try again.';
            }
            results.add(r);
        }
        return results;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }
}