/**
 * ZentraMutualFundService
 * @description Invocable Apex service to retrieve mutual fund / SIP holdings
 *              for a verified customer. Used by the TruZentra Agentforce topic
 *              "Mutual Fund Info". Returns formatted summary or detail.
 * @developer   BlueForce Team
 * @date        2026-06-01
 */
public without sharing class ZentraMutualFundService {

    public class MFRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='SIP Index' description='1-based index of a specific SIP to show full details for. Leave 0 or blank for quick summary.' required=false)
        public Decimal sipIndex;

        @InvocableVariable(label='Include Inactive' description='If true, includes Paused, Completed, and Cancelled SIPs. Defaults to false (Active only).' required=false)
        public Boolean includeInactive;

        @InvocableVariable(label='Language' description='Language code: hi for Hindi, en for English. Defaults to en.' required=false)
        public String language;
    }

    public class MFResult {
        @InvocableVariable(label='Mutual Fund Summary' description='Formatted mutual fund / SIP summary. Display this exactly as-is to the customer.')
        public String outputMessage;

        @InvocableVariable(label='Success' description='Whether the operation succeeded')
        public Boolean success;
    }

    @InvocableMethod(label='Get Mutual Fund Holdings'
        description='Fetches SIP / mutual fund holdings for the authenticated customer. Quick summary (sipIndex=0) or full detail (sipIndex=1,2...).'
        category='Financial Services')
    public static List<MFResult> getMutualFundHoldings(List<MFRequest> requests) {
        List<MFResult> results = new List<MFResult>();

        for (MFRequest req : requests) {
            MFResult r = new MFResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.outputMessage = 'Customer Id is required.';
                    results.add(r);
                    continue;
                }

                Boolean includeInactive = req.includeInactive == true;
                Integer idx = (req.sipIndex != null) ? Integer.valueOf(req.sipIndex) : 0;

                String statusFilter = includeInactive ? '' : 'Active';
                List<FinServ__FinancialHolding__c> sips;
                if (String.isNotBlank(statusFilter)) {
                    sips = [
                        SELECT Fund_Name__c, Folio_Number__c, SIP_Amount__c, Frequency__c,
                               SIP_Day__c, Status__c, Start_Date__c, End_Date__c,
                               FinServ__Shares__c, Total_Invested__c, FinServ__MarketValue__c,
                               Installments_Completed__c, Next_Installment_Date__c, Remarks__c,
                               Source_Account__r.Name
                        FROM FinServ__FinancialHolding__c
                        WHERE FinServ__PrimaryOwner__c = :req.customerId
                          AND Status__c = :statusFilter
                        ORDER BY FinServ__MarketValue__c DESC NULLS LAST
                        LIMIT 20
                    ];
                } else {
                    sips = [
                        SELECT Fund_Name__c, Folio_Number__c, SIP_Amount__c, Frequency__c,
                               SIP_Day__c, Status__c, Start_Date__c, End_Date__c,
                               FinServ__Shares__c, Total_Invested__c, FinServ__MarketValue__c,
                               Installments_Completed__c, Next_Installment_Date__c, Remarks__c,
                               Source_Account__r.Name
                        FROM FinServ__FinancialHolding__c
                        WHERE FinServ__PrimaryOwner__c = :req.customerId
                        ORDER BY Status__c, FinServ__MarketValue__c DESC NULLS LAST
                        LIMIT 20
                    ];
                }

                if (sips.isEmpty()) {
                    r.success = true;
                    r.outputMessage = 'No mutual fund / SIP holdings found on your account.';
                    results.add(r);
                    continue;
                }

                if (idx > 0) {
                    r = buildDetailView(sips, idx);
                } else {
                    r = buildSummaryView(sips);
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraMutualFundService', 'getMutualFundHoldings', e,
                    req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.outputMessage = 'Something went wrong while fetching your mutual fund details. Please try again.';
            }
            results.add(r);
        }
        return results;
    }

    private static MFResult buildSummaryView(List<FinServ__FinancialHolding__c> sips) {
        MFResult r = new MFResult();
        r.success = true;

        Decimal totalInvested = 0;
        Decimal totalValue = 0;

        String msg = '\ud83d\udcca *Your Mutual Fund / SIP Portfolio*\n\n';

        Integer i = 1;
        for (FinServ__FinancialHolding__c s : sips) {
            String statusIcon = s.Status__c == 'Active' ? '\u2705' : (s.Status__c == 'Paused' ? '\u23f8\ufe0f' : '\u274c');
            Decimal invested = s.Total_Invested__c != null ? s.Total_Invested__c : 0;
            Decimal curVal = s.FinServ__MarketValue__c != null ? s.FinServ__MarketValue__c : 0;
            Decimal gain = curVal - invested;
            String gainStr = (gain >= 0 ? '+' : '') + '\u20b9' + formatNum(gain);

            msg += '*' + i + '.* ' + statusIcon + ' ' + s.Fund_Name__c + '\n';
            msg += '   SIP: \u20b9' + formatNum(s.SIP_Amount__c) + '/' + s.Frequency__c;
            msg += ' \u2022 Invested: \u20b9' + formatNum(invested);
            msg += ' \u2022 Value: \u20b9' + formatNum(curVal);
            msg += ' (' + gainStr + ')\n\n';

            totalInvested += invested;
            totalValue += curVal;
            i++;
        }

        Decimal totalGain = totalValue - totalInvested;
        Decimal returnPct = totalInvested > 0 ? ((totalGain / totalInvested) * 100) : 0;
        String totalGainStr = (totalGain >= 0 ? '+' : '') + '\u20b9' + formatNum(totalGain);

        msg += '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n';
        msg += '\ud83d\udcb0 *Total Invested:* \u20b9' + formatNum(totalInvested) + '\n';
        msg += '\ud83d\udcc8 *Current Value:* \u20b9' + formatNum(totalValue) + '\n';
        msg += (totalGain >= 0 ? '\ud83d\ude80' : '\ud83d\udcc9') + ' *Overall Returns:* ' + totalGainStr + ' (' + returnPct.setScale(1) + '%)\n\n';
        msg += 'Reply with a number (1\u2013' + sips.size() + ') for full details of a specific SIP.';

        r.outputMessage = msg;
        return r;
    }

    private static MFResult buildDetailView(List<FinServ__FinancialHolding__c> sips, Integer idx) {
        MFResult r = new MFResult();

        if (idx < 1 || idx > sips.size()) {
            r.success = false;
            r.outputMessage = 'Invalid selection. Please choose a number between 1 and ' + sips.size() + '.';
            return r;
        }

        r.success = true;
        FinServ__FinancialHolding__c s = sips[idx - 1];

        Decimal invested = s.Total_Invested__c != null ? s.Total_Invested__c : 0;
        Decimal curVal = s.FinServ__MarketValue__c != null ? s.FinServ__MarketValue__c : 0;
        Decimal gain = curVal - invested;
        Decimal returnPct = invested > 0 ? ((gain / invested) * 100) : 0;
        String gainStr = (gain >= 0 ? '+' : '') + '\u20b9' + formatNum(gain);

        String statusIcon = s.Status__c == 'Active' ? '\u2705' : (s.Status__c == 'Paused' ? '\u23f8\ufe0f' : '\u274c');

        String msg = '\ud83d\udcca *SIP Detail \u2014 ' + s.Fund_Name__c + '*\n\n';
        msg += '\ud83c\udfe6 *Fund:* ' + s.Fund_Name__c + '\n';
        msg += '\ud83d\udcc1 *Folio:* ' + (s.Folio_Number__c != null ? s.Folio_Number__c : '\u2014') + '\n';
        msg += statusIcon + ' *Status:* ' + s.Status__c + '\n';
        msg += '\ud83d\udcb5 *SIP Amount:* \u20b9' + formatNum(s.SIP_Amount__c) + ' / ' + s.Frequency__c + '\n';
        msg += '\ud83d\udcc5 *SIP Day:* ' + (s.SIP_Day__c != null ? String.valueOf(Integer.valueOf(s.SIP_Day__c)) + 'th of every month' : '\u2014') + '\n';
        msg += '\ud83d\udcc6 *Start Date:* ' + (s.Start_Date__c != null ? s.Start_Date__c.format() : '\u2014') + '\n';
        if (s.End_Date__c != null) {
            msg += '\ud83d\udcc6 *End Date:* ' + s.End_Date__c.format() + '\n';
        }
        msg += '\n';
        msg += '\ud83d\udcb0 *Total Invested:* \u20b9' + formatNum(invested) + '\n';
        msg += '\ud83d\udcc8 *Current Value:* \u20b9' + formatNum(curVal) + '\n';
        msg += (gain >= 0 ? '\ud83d\ude80' : '\ud83d\udcc9') + ' *Returns:* ' + gainStr + ' (' + returnPct.setScale(1) + '%)\n';
        msg += '\ud83d\udce6 *Units Held:* ' + (s.FinServ__Shares__c != null ? String.valueOf(s.FinServ__Shares__c.setScale(2)) : '0') + '\n';
        msg += '\ud83d\udd22 *Installments Done:* ' + (s.Installments_Completed__c != null ? String.valueOf(Integer.valueOf(s.Installments_Completed__c)) : '0') + '\n';
        if (s.Next_Installment_Date__c != null) {
            msg += '\u23f0 *Next Installment:* ' + s.Next_Installment_Date__c.format() + '\n';
        }
        if (s.Source_Account__r != null && s.Source_Account__r.Name != null) {
            msg += '\ud83c\udfe6 *Debit Account:* ' + s.Source_Account__r.Name + '\n';
        }
        if (String.isNotBlank(s.Remarks__c)) {
            msg += '\ud83d\udcdd *Remarks:* ' + s.Remarks__c + '\n';
        }

        r.outputMessage = msg;
        return r;
    }

    private static String formatNum(Decimal val) {
        if (val == null) return '0';
        return String.valueOf(val.setScale(0).longValue());
    }
}
