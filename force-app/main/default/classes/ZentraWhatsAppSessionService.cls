/**
 * @description Invocable Apex service to extract the customer's phone number from
 *              the active WhatsApp MessagingSession. Used by OTP flows to auto-detect
 *              the customer's phone when messaging via WhatsApp/Agentforce.
 * @author      BlueForce Team
 * @date        2026-04-10
 */
public without sharing class ZentraWhatsAppSessionService {

    public class PhoneRequest {
        @InvocableVariable(label='Fallback Phone Number' description='Phone number to use if WhatsApp session is not found (optional)' required=false)
        public String fallbackPhone;

        @InvocableVariable(label='Messaging Session Id' description='MessagingSession Id from current conversation context (optional — used to scope the query to the exact session)' required=false)
        public String messagingSessionId;
    }

    public class PhoneResponse {
        @InvocableVariable(label='Phone Number' description='Customer phone number detected from WhatsApp session or fallback')
        public String phoneNumber;

        @InvocableVariable(label='Detected From WhatsApp' description='Whether the phone was auto-detected from WhatsApp session')
        public Boolean detectedFromWhatsApp;

        @InvocableVariable(label='Success' description='Whether a phone number was resolved')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message')
        public String message;
    }

    /**
     * @description Finds the customer's phone number from the most recent active MessagingSession.
     *              Falls back to the provided phone number if no active WhatsApp session is found.
     * @param requests List of PhoneRequest
     * @return List of PhoneResponse with the resolved phone number
     */
    @InvocableMethod(label='Get WhatsApp Customer Phone' description='Detects the customer phone number from the active WhatsApp messaging session. Returns the phone number for OTP verification.' category='Authentication')
    public static List<PhoneResponse> getCustomerPhone(List<PhoneRequest> requests) {
        List<PhoneResponse> responses = new List<PhoneResponse>();

        for (PhoneRequest req : requests) {
            PhoneResponse resp = new PhoneResponse();

            try {
                // Always use the phone number provided by the agent (customer provides it)
                // Session auto-detection is disabled to avoid picking up wrong sessions
                if (String.isNotBlank(req.fallbackPhone)) {
                    resp.phoneNumber = req.fallbackPhone;
                    resp.detectedFromWhatsApp = false;
                    resp.success = true;
                    resp.message = 'Using provided phone number.';
                } else {
                    resp.phoneNumber = null;
                    resp.detectedFromWhatsApp = false;
                    resp.success = false;
                    resp.message = 'No active WhatsApp session found and no phone number provided. Please provide your registered mobile number.';
                }

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'ZentraWhatsAppSessionService error: ' + e.getMessage());
                // Fallback gracefully
                if (String.isNotBlank(req.fallbackPhone)) {
                    resp.phoneNumber = req.fallbackPhone;
                    resp.detectedFromWhatsApp = false;
                    resp.success = true;
                    resp.message = 'Using provided phone number.';
                } else {
                    resp.success = false;
                    resp.message = 'Unable to detect phone number. Please provide your registered mobile number.';
                }
            }

            responses.add(resp);
        }

        return responses;
    }

    /**
     * @description Cleans the MessagingPlatformKey to extract a standard phone number.
     *              WhatsApp keys are typically in format: "whatsapp:+919876543210" or just "+919876543210"
     * @param platformKey The raw platform key from MessagingEndUser
     * @return Cleaned phone number string
     */
    @TestVisible
    private static String cleanPhoneNumber(String platformKey) {
        if (String.isBlank(platformKey)) {
            return null;
        }
        // Remove 'whatsapp:' prefix if present
        String phone = platformKey.replaceAll('(?i)whatsapp:', '').trim();
        // Remove any non-digit characters except leading +
        if (phone.startsWith('+')) {
            phone = '+' + phone.substring(1).replaceAll('[^0-9]', '');
        } else {
            phone = phone.replaceAll('[^0-9]', '');
        }
        return String.isBlank(phone) ? null : phone;
    }
}