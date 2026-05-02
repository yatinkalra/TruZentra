/**
 * ZentraRecurringPaymentService
 * @description Invocable Apex service to retrieve recurring payment (standing instruction) details
 *              for an authenticated customer. Supports two modes:
 *              (1) Quick summary (default) — compact one-liner per payment with payee, amount, frequency.
 *              (2) Detail mode — when paymentIndex is provided, returns full details for that specific payment.
 *              Designed to be called from Flows and Agentforce Actions.
 * @developer   BlueForce Team
 * @date        2026-04-20
 */
public without sharing class ZentraRecurringPaymentService {

    public class RecurringPaymentRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='Language' description='Language code: hi for Hindi, en for English. Defaults to en.' required=false)
        public String language;

        @InvocableVariable(label='Include Inactive' description='If true, includes Paused, Completed, and Cancelled instructions. Defaults to false (Active only).' required=false)
        public Boolean includeInactive;

        @InvocableVariable(label='Payment Index' description='1-based index of a specific payment to show full details for. Leave blank or 0 to show the quick summary of all payments.' required=false)
        public Integer paymentIndex;
    }

    public class RecurringPaymentResult {
        @InvocableVariable(label='Success' description='Whether recurring payments were found')
        public Boolean success;

        @InvocableVariable(label='Summary' description='Formatted recurring payment summary for the customer')
        public String summary;

        @InvocableVariable(label='Payment Count' description='Total number of recurring payments returned')
        public Integer paymentCount;
    }

    @InvocableMethod(label='Get Recurring Payments'
        description='Returns recurring payments (standing instructions) for a customer. Default: quick summary. Set paymentIndex (1-based) for full details of a specific payment.'
        category='Account Inquiry')
    public static List<RecurringPaymentResult> getRecurringPayments(List<RecurringPaymentRequest> requests) {
        List<RecurringPaymentResult> results = new List<RecurringPaymentResult>();

        for (RecurringPaymentRequest req : requests) {
            RecurringPaymentResult r = new RecurringPaymentResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.summary = 'Customer Id is required.';
                    r.paymentCount = 0;
                    results.add(r);
                    continue;
                }

                Boolean showAll = req.includeInactive == true;
                String lang = String.isNotBlank(req.language) ? req.language.toLowerCase().trim() : 'en';
                Integer detailIdx = (req.paymentIndex != null && req.paymentIndex > 0) ? req.paymentIndex : 0;

                List<Zentra_Recurring_Payment__c> payments = queryPayments(req.customerId, showAll);

                if (payments.isEmpty()) {
                    r.success = false;
                    r.summary = (lang == 'hi')
                        ? 'आपके खाते पर कोई सक्रिय स्थायी निर्देश (standing instruction) नहीं मिला।'
                        : 'No active recurring payments (standing instructions) found on your account.';
                    r.paymentCount = 0;
                } else if (detailIdx > 0) {
                    // Detail mode — show full info for one specific payment
                    if (detailIdx > payments.size()) {
                        r.success = false;
                        r.summary = (lang == 'hi')
                            ? 'अमान्य क्रमांक। कृपया 1 से ' + payments.size() + ' के बीच कोई संख्या चुनें।'
                            : 'Invalid number. Please pick a number between 1 and ' + payments.size() + '.';
                        r.paymentCount = payments.size();
                    } else {
                        r.success = true;
                        r.summary = formatDetailView(payments.get(detailIdx - 1), detailIdx, lang);
                        r.paymentCount = payments.size();
                    }
                } else {
                    // Quick summary mode — compact one-liner per payment
                    r.success = true;
                    r.summary = formatQuickSummary(payments, lang, showAll);
                    r.paymentCount = payments.size();
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraRecurringPaymentService', 'getRecurringPayments', e,
                    req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.summary = 'Something went wrong while retrieving your recurring payments. Please try again.';
                r.paymentCount = 0;
            }
            results.add(r);
        }
        return results;
    }

    private static List<Zentra_Recurring_Payment__c> queryPayments(String customerId, Boolean showAll) {
        String query = 'SELECT Name, Payee_Name__c, Payee_Account_Number__c, Amount__c, '
                     + 'Frequency__c, Start_Date__c, End_Date__c, Next_Payment_Date__c, '
                     + 'Last_Payment_Date__c, Status__c, Payment_Purpose__c, Remarks__c, '
                     + 'Source_Account__r.Name, Source_Account__r.FinServ__FinancialAccountType__c '
                     + 'FROM Zentra_Recurring_Payment__c '
                     + 'WHERE Customer__c = :customerId ';

        if (!showAll) {
            query += 'AND Status__c = \'Active\' ';
        }
        query += 'ORDER BY Next_Payment_Date__c ASC NULLS LAST, Start_Date__c ASC LIMIT 50';

        return Database.query(query);
    }

    // ─── Quick Summary Mode: compact one-liner per payment ───
    private static String formatQuickSummary(List<Zentra_Recurring_Payment__c> payments, String lang, Boolean showAll) {
        Boolean isHindi = (lang == 'hi');
        String sep = '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

        String header = isHindi
            ? '🔄 *आपके स्थायी निर्देश (Standing Instructions)*'
            : '🔄 *Your Recurring Payments (Standing Instructions)*';

        String subtitle = isHindi
            ? '📋 कुल: ' + payments.size() + (showAll ? ' (सभी)' : ' सक्रिय')
            : '📋 Total: ' + payments.size() + (showAll ? ' (all)' : ' active');

        String body = header + '\n' + subtitle + sep;

        Integer idx = 1;
        for (Zentra_Recurring_Payment__c p : payments) {
            body += formatOneLiner(p, idx, isHindi);
            idx++;
        }

        body += sep;
        body += isHindi
            ? '👆 _किसी भी भुगतान का पूरा विवरण देखने के लिए उसका नंबर बताएं (जैसे "2 दिखाओ")_'
            : '👆 _Reply with a number to see full details (e.g. "show 2")_';

        return body;
    }

    private static String formatOneLiner(Zentra_Recurring_Payment__c p, Integer idx, Boolean isHindi) {
        String payee = p.Payee_Name__c != null ? p.Payee_Name__c : '—';
        String amount = p.Amount__c != null ? '₹' + formatCurrency(p.Amount__c) : '—';
        String freq = p.Frequency__c != null ? p.Frequency__c : '—';
        String status = p.Status__c != null ? p.Status__c : '';

        String statusEmoji = '✅';
        if (status == 'Paused') statusEmoji = '⏸️';
        else if (status == 'Completed') statusEmoji = '✔️';
        else if (status == 'Cancelled') statusEmoji = '❌';

        String freqLabel = isHindi ? getFrequencyHindi(freq) : freq;

        return '*' + idx + '.* ' + statusEmoji + ' ' + payee + ' — *' + amount + '* / ' + freqLabel + '\n';
    }

    // ─── Detail Mode: full info for a single payment ───
    private static String formatDetailView(Zentra_Recurring_Payment__c p, Integer idx, String lang) {
        Boolean isHindi = (lang == 'hi');
        String sep = '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

        String payee = p.Payee_Name__c != null ? p.Payee_Name__c : '—';
        String amount = p.Amount__c != null ? '₹' + formatCurrency(p.Amount__c) : '—';
        String freq = p.Frequency__c != null ? p.Frequency__c : '—';
        String status = p.Status__c != null ? p.Status__c : '—';
        String purpose = p.Payment_Purpose__c != null ? p.Payment_Purpose__c : '—';
        String nextDate = p.Next_Payment_Date__c != null ? p.Next_Payment_Date__c.format() : '—';
        String endDate = p.End_Date__c != null ? p.End_Date__c.format() : (isHindi ? 'अनिश्चित काल' : 'Indefinite');
        String lastDate = p.Last_Payment_Date__c != null ? p.Last_Payment_Date__c.format() : '—';
        String startDate = p.Start_Date__c != null ? p.Start_Date__c.format() : '—';
        String payeeAcct = p.Payee_Account_Number__c != null ? p.Payee_Account_Number__c : '—';
        String remarks = p.Remarks__c != null ? p.Remarks__c : '';
        String refNum = p.Name != null ? p.Name : '—';
        String sourceAcct = '';
        if (p.Source_Account__r != null && p.Source_Account__r.Name != null) {
            sourceAcct = p.Source_Account__r.Name;
            if (p.Source_Account__r.FinServ__FinancialAccountType__c != null) {
                sourceAcct += ' (' + p.Source_Account__r.FinServ__FinancialAccountType__c + ')';
            }
        }

        String statusEmoji = '✅';
        if (status == 'Paused') statusEmoji = '⏸️';
        else if (status == 'Completed') statusEmoji = '✔️';
        else if (status == 'Cancelled') statusEmoji = '❌';

        String freqLabel = isHindi ? getFrequencyHindi(freq) : freq;

        String body = '';
        if (isHindi) {
            body += '🔍 *स्थायी निर्देश #' + idx + ' — विस्तृत जानकारी*' + sep;
            body += '📌 *भुगतान प्राप्तकर्ता:* ' + payee + '\n';
            body += '🔢 *संदर्भ:* ' + refNum + '\n';
            body += '💰 *राशि:* ' + amount + '\n';
            body += '🔄 *आवृत्ति:* ' + freqLabel + '\n';
            body += '📌 *उद्देश्य:* ' + purpose + '\n';
            body += '📊 *स्थिति:* ' + status + ' ' + statusEmoji + '\n';
            body += sep;
            body += '📅 *अगला भुगतान:* ' + nextDate + '\n';
            body += '🕐 *आखिरी भुगतान:* ' + lastDate + '\n';
            body += '📆 *शुरू:* ' + startDate + '\n';
            body += '🏁 *समाप्ति:* ' + endDate + '\n';
            body += sep;
            body += '🏦 *डेबिट खाता:* ' + (String.isNotBlank(sourceAcct) ? sourceAcct : '—') + '\n';
            body += '🔑 *प्राप्तकर्ता खाता:* ' + payeeAcct + '\n';
            if (String.isNotBlank(remarks)) {
                body += '� *टिप्पणी:* ' + remarks + '\n';
            }
        } else {
            body += '🔍 *Standing Instruction #' + idx + ' — Full Details*' + sep;
            body += '📌 *Payee:* ' + payee + '\n';
            body += '🔢 *Reference:* ' + refNum + '\n';
            body += '💰 *Amount:* ' + amount + '\n';
            body += '🔄 *Frequency:* ' + freqLabel + '\n';
            body += '📌 *Purpose:* ' + purpose + '\n';
            body += '📊 *Status:* ' + status + ' ' + statusEmoji + '\n';
            body += sep;
            body += '📅 *Next Payment:* ' + nextDate + '\n';
            body += '🕐 *Last Paid:* ' + lastDate + '\n';
            body += '📆 *Started:* ' + startDate + '\n';
            body += '🏁 *Valid Until:* ' + endDate + '\n';
            body += sep;
            body += '🏦 *Debit From:* ' + (String.isNotBlank(sourceAcct) ? sourceAcct : '—') + '\n';
            body += '🔑 *Payee Account:* ' + payeeAcct + '\n';
            if (String.isNotBlank(remarks)) {
                body += '� *Remarks:* ' + remarks + '\n';
            }
        }

        return body;
    }

    private static String getFrequencyHindi(String freq) {
        Map<String, String> freqMap = new Map<String, String>{
            'Daily'       => 'दैनिक',
            'Weekly'      => 'साप्ताहिक',
            'Monthly'     => 'मासिक',
            'Quarterly'   => 'तिमाही',
            'Half-Yearly' => 'छमाही',
            'Yearly'      => 'वार्षिक'
        };
        return freqMap.containsKey(freq) ? freqMap.get(freq) : freq;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }
}