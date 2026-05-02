/**
 * ZentraAccountLookupService
 * @description Finds an Account by phone number with flexible matching.
 *              Matches with or without country code (+91), leading 0, etc.
 *              Replaces the Get Records lookup in the OTP flow to support
 *              all phone number formats.
 * @developer   BlueForce Team
 * @date        2026-04-27
 */
public without sharing class ZentraAccountLookupService {

    public class LookupRequest {
        @InvocableVariable(label='Phone Number' description='Customer phone number to search (with or without +91)' required=true)
        public String phoneNumber;
    }

    public class LookupResponse {
        @InvocableVariable(label='Account Found' description='Whether an account was found')
        public Boolean accountFound;

        @InvocableVariable(label='Account Id' description='Account Id if found')
        public Id accountId;

        @InvocableVariable(label='Account Name' description='Account Name if found')
        public String accountName;

        @InvocableVariable(label='Normalized Phone' description='Normalized phone number with +91 prefix')
        public String normalizedPhone;

        @InvocableVariable(label='Message' description='Status message')
        public String message;
    }

    @InvocableMethod(label='Find Account By Phone'
        description='Finds an Account by phone number, matching with or without +91 country code prefix.'
        category='Authentication')
    public static List<LookupResponse> findAccount(List<LookupRequest> requests) {
        List<LookupResponse> results = new List<LookupResponse>();
        for (LookupRequest req : requests) {
            results.add(lookupByPhone(req.phoneNumber));
        }
        return results;
    }

    private static LookupResponse lookupByPhone(String phone) {
        LookupResponse resp = new LookupResponse();

        if (String.isBlank(phone)) {
            resp.accountFound = false;
            resp.message = 'Phone number is required. Please provide your registered mobile number.';
            return resp;
        }

        String normalized = normalizePhone(phone);
        resp.normalizedPhone = normalized;

        Set<String> variants = phoneVariants(phone);
        if (variants.isEmpty()) {
            resp.accountFound = false;
            resp.message = 'Invalid phone number format. Please provide a valid 10-digit mobile number.';
            return resp;
        }

        List<Account> accts = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Phone IN :variants
            LIMIT 1
        ];

        if (!accts.isEmpty()) {
            resp.accountFound = true;
            resp.accountId = accts[0].Id;
            resp.accountName = accts[0].Name;
            resp.message = 'Account found.';
        } else {
            resp.accountFound = false;
            resp.message = 'ACCOUNT_NOT_FOUND: No account found for this phone number. The customer may be a new prospect.';
        }
        return resp;
    }

    /**
     * @description Normalizes a phone number to +91 format.
     *              Handles: ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE, 91ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE, +91ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE, 0ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE
     */
    @TestVisible
    static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        String cleaned = phone.replaceAll('[^0-9+]', '').trim();
        if (String.isBlank(cleaned)) return null;

        String digits = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;

        // Remove leading 0 (trunk prefix)
        if (digits.startsWith('0') && digits.length() > 10) {
            digits = digits.substring(1);
        }
        // 10 digits → add +91
        if (digits.length() == 10) {
            return '+91' + digits;
        }
        // 91 + 10 digits → add +
        if (digits.startsWith('91') && digits.length() == 12) {
            return '+' + digits;
        }
        // Already has +
        if (cleaned.startsWith('+')) {
            return cleaned;
        }
        return '+' + digits;
    }

    /**
     * @description Builds all possible phone variants for Account.Phone matching.
     */
    @TestVisible
    static Set<String> phoneVariants(String phone) {
        Set<String> variants = new Set<String>();
        if (String.isBlank(phone)) return variants;

        String normalized = normalizePhone(phone);
        if (normalized == null) return variants;

        variants.add(normalized);                              // +91ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE
        String digits = normalized.replaceAll('[^0-9]', '');
        if (digits.startsWith('91') && digits.length() == 12) {
            variants.add(digits.substring(2));                 // ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE
            variants.add('0' + digits.substring(2));           // 0ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE
            variants.add(digits);                              // 91ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE
        }
        return variants;
    }
}
