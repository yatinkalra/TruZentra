/**
 * ZentraRestructuringStatusService
 * @description Returns the current status of loan restructuring requests for an
 *              authenticated customer. Queries Loan_Restructuring_Request__c and
 *              returns formatted status with selected option, new EMI, savings,
 *              and RM callback schedule.
 * @developer   BlueForce Team
 * @date        2026-04-17
 */
public without sharing class ZentraRestructuringStatusService {

    @InvocableMethod(label='Get Restructuring Status'
        description='Returns the current status of all loan restructuring requests for an authenticated customer. Shows selected option, new EMI, monthly savings, status, and RM callback details.'
        category='Loan Services')
    public static List<RestructuringStatusResult> getRestructuringStatus(List<RestructuringStatusRequest> requests) {
        List<RestructuringStatusResult> results = new List<RestructuringStatusResult>();

        for (RestructuringStatusRequest req : requests) {
            RestructuringStatusResult r = new RestructuringStatusResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer Id is required.';
                    r.requestCount = 0;
                    results.add(r);
                    continue;
                }

                List<Loan_Restructuring_Request__c> reqs = [
                    SELECT Name, Status__c, Selected_Option__c,
                           New_EMI__c, Original_EMI__c, Monthly_Savings__c,
                           New_Tenure_Months__c, Additional_Interest__c,
                           OTP_Confirmed__c, RM_Callback_Scheduled__c,
                           Loan_Financial_Account__r.Name,
                           Loan_Financial_Account__r.FinServ__FinancialAccountType__c,
                           CreatedDate
                    FROM Loan_Restructuring_Request__c
                    WHERE Customer__c = :req.customerId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (reqs.isEmpty()) {
                    r.success = true;
                    r.requestCount = 0;
                    r.message = 'No loan restructuring requests found for your account.';
                    r.statusSummary = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Restructuring Status\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\nNo restructuring requests found on your account.\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━';
                } else {
                    r.success = true;
                    r.requestCount = reqs.size();
                    r.statusSummary = formatRestructuringStatus(reqs);
                    r.message = 'Restructuring status retrieved successfully.';
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraRestructuringStatusService', 'getRestructuringStatus', e);
                r.success = false;
                r.message = 'Error retrieving restructuring status: ' + e.getMessage();
                r.requestCount = 0;
            }
            results.add(r);
        }
        return results;
    }

    private static String formatRestructuringStatus(List<Loan_Restructuring_Request__c> reqs) {
        Map<String, String> statusEmojis = new Map<String, String>{
            'Pending'    => '⏳',
            'Submitted'  => '📤',
            'Approved'   => '✅',
            'Rejected'   => '❌',
            'OTP Confirmed' => '🔐'
        };

        Map<String, String> optionLabels = new Map<String, String>{
            'A' => 'Extend 1 Year (+12 months)',
            'B' => 'Extend 2 Years (+24 months)',
            'C' => '3-Month Moratorium'
        };

        Loan_Restructuring_Request__c lr = reqs[0];
        String status = lr.Status__c != null ? lr.Status__c : 'Pending';
        String emoji = statusEmojis.containsKey(status) ? statusEmojis.get(status) : '📋';
        String optLabel = optionLabels.containsKey(lr.Selected_Option__c) ? optionLabels.get(lr.Selected_Option__c) : lr.Selected_Option__c;

        String output = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Your Latest Restructuring Status\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

        output += emoji + ' Request #' + lr.Name + '\n';
        output += '   Status:     ' + status + '\n';
        output += '   Loan:       ' + (lr.Loan_Financial_Account__r != null ? lr.Loan_Financial_Account__r.Name : 'N/A') + '\n';
        output += '   Option:     ' + (lr.Selected_Option__c != null ? lr.Selected_Option__c + ' — ' + optLabel : 'N/A') + '\n';
        output += '   Old EMI:    ₹' + formatCurrency(lr.Original_EMI__c) + '/month\n';
        output += '   New EMI:    ₹' + formatCurrency(lr.New_EMI__c) + '/month\n';

        if (lr.Monthly_Savings__c != null && lr.Monthly_Savings__c > 0) {
            output += '   💰 Saving:  ₹' + formatCurrency(lr.Monthly_Savings__c) + '/month\n';
        }

        output += '   Tenure:     ' + (lr.New_Tenure_Months__c != null ? Integer.valueOf(lr.New_Tenure_Months__c) + ' months' : 'N/A') + '\n';
        output += '   Extra Int:  ₹' + formatCurrency(lr.Additional_Interest__c) + '\n';

        if (lr.RM_Callback_Scheduled__c != null) {
            output += '   📞 RM Call:  ' + lr.RM_Callback_Scheduled__c.format('dd-MMM-yyyy hh:mm a') + '\n';
        }

        output += '   Filed:      ' + lr.CreatedDate.format('dd-MMM-yyyy') + '\n';

        output += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

        return output;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }

    public class RestructuringStatusRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;
    }

    public class RestructuringStatusResult {
        @InvocableVariable(label='Success' description='Whether restructuring status was retrieved successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message')
        public String message;

        @InvocableVariable(label='Status Summary' description='Formatted restructuring status string with all details')
        public String statusSummary;

        @InvocableVariable(label='Request Count' description='Number of restructuring requests found')
        public Integer requestCount;
    }
}