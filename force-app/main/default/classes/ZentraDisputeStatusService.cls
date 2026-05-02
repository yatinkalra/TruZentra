/**
 * ZentraDisputeStatusService
 * @description Returns the current status of dispute cases for an authenticated customer.
 *              Two modes:
 *              1. List mode (caseNumber blank) — returns ALL disputes as a numbered summary list.
 *              2. Detail mode (caseNumber provided) — returns expanded detail for one dispute.
 * @developer   BlueForce Team
 * @date        2026-04-17
 */
public without sharing class ZentraDisputeStatusService {

    private static final Map<String, String> STAGE_EMOJIS = new Map<String, String>{
        'Filed'                => '📝',
        'Under Investigation'  => '🔍',
        'Provisional Credit'   => '💰',
        'Resolved'             => '✅',
        'Rejected'             => '❌',
        'Closed'               => '✅'
    };

    @InvocableMethod(label='Get Dispute Status'
        description='Returns dispute status. If caseNumber is blank, returns ALL disputes as a numbered list. If caseNumber is provided, returns full detail for that specific case.'
        category='Dispute Management')
    public static List<DisputeStatusResult> getDisputeStatus(List<DisputeStatusRequest> requests) {
        List<DisputeStatusResult> results = new List<DisputeStatusResult>();

        Id disputeRT;
        try {
            disputeRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraDisputeStatusService', 'getDisputeStatus', e);
            DisputeStatusResult errResult = new DisputeStatusResult();
            errResult.success = false;
            errResult.message = 'Dispute record type not configured. Please contact support.';
            errResult.disputeCount = 0;
            results.add(errResult);
            return results;
        }

        for (DisputeStatusRequest req : requests) {
            DisputeStatusResult r = new DisputeStatusResult();
            try {
                if (String.isBlank(req.customerId)) {
                    r.success = false;
                    r.message = 'Customer Id is required.';
                    r.disputeCount = 0;
                    results.add(r);
                    continue;
                }

                List<Case> disputes = [
                    SELECT CaseNumber, Subject, Status, Dispute_Stage__c,
                           Dispute_Amount__c, Provisional_Credit_Issued__c,
                           Provisional_Credit_Amount__c, Estimated_Resolution_Date__c,
                           CreatedDate, LastModifiedDate, ClosedDate
                    FROM Case
                    WHERE AccountId = :req.customerId
                      AND RecordTypeId = :disputeRT
                    ORDER BY CreatedDate DESC
                    LIMIT 20
                ];

                if (disputes.isEmpty()) {
                    r.success = true;
                    r.disputeCount = 0;
                    r.message = 'No dispute cases found for your account.';
                    r.statusSummary = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Dispute Status\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\nNo disputes found on your account.\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━';
                } else if (String.isNotBlank(req.caseNumber)) {
                    // Detail mode — expand a specific dispute by case number
                    Case target = null;
                    for (Case d : disputes) {
                        if (d.CaseNumber == req.caseNumber) {
                            target = d;
                            break;
                        }
                    }
                    if (target != null) {
                        r.success = true;
                        r.disputeCount = 1;
                        r.statusSummary = formatDisputeDetail(target);
                        r.message = 'Dispute detail retrieved successfully.';
                    } else {
                        r.success = false;
                        r.disputeCount = disputes.size();
                        r.message = 'Case #' + req.caseNumber + ' not found among your disputes. Please check the case number.';
                    }
                } else {
                    // List mode — numbered summary of ALL disputes
                    r.success = true;
                    r.disputeCount = disputes.size();
                    r.statusSummary = formatDisputeList(disputes);
                    r.message = 'Found ' + disputes.size() + ' dispute(s). Reply with the number to see full details.';
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraDisputeStatusService', 'getDisputeStatus', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.message = 'Error retrieving dispute status: ' + e.getMessage();
                r.disputeCount = 0;
            }
            results.add(r);
        }
        return results;
    }

    // ─── List mode: compact numbered list showing only dispute name ───
    private static String formatDisputeList(List<Case> disputes) {
        String[] numberEmojis = new String[]{ '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟' };

        String output = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Your Dispute Cases (' + disputes.size() + ')\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

        for (Integer i = 0; i < disputes.size(); i++) {
            Case d = disputes[i];
            String numEmoji = i < numberEmojis.size() ? numberEmojis[i] : '(' + (i + 1) + ')';
            String disputeName = d.Subject != null ? d.Subject : 'Dispute Case #' + d.CaseNumber;

            output += numEmoji + ' ' + disputeName + '  (Case #' + d.CaseNumber + ')\n';
        }

        output += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += '💬 Reply with a number to see status, amount, and full details.\n';

        return output;
    }

    // ─── Detail mode: full info for a single dispute ───
    private static String formatDisputeDetail(Case d) {
        String stage = d.Dispute_Stage__c != null ? d.Dispute_Stage__c : d.Status;
        String emoji = STAGE_EMOJIS.containsKey(stage) ? STAGE_EMOJIS.get(stage) : '📋';

        String output = '━━━━━━━━━━━━━━━━━━━━━━━━━━\n📋 Dispute Detail — Case #' + d.CaseNumber + '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

        output += emoji + ' Case #' + d.CaseNumber + '\n';
        output += '   Subject:    ' + (d.Subject != null ? d.Subject : 'Dispute Case') + '\n';
        output += '   Stage:      ' + stage + '\n';
        output += '   Amount:     ₹' + formatCurrency(d.Dispute_Amount__c) + '\n';

        if (d.Provisional_Credit_Issued__c != null && d.Provisional_Credit_Issued__c) {
            output += '   💳 Credit:  ₹' + formatCurrency(d.Provisional_Credit_Amount__c) + ' (provisional credit issued)\n';
        }

        if (d.Estimated_Resolution_Date__c != null) {
            output += '   📅 Resolve:  By ' + d.Estimated_Resolution_Date__c.format() + '\n';
        }

        output += '   Filed:      ' + d.CreatedDate.format('dd-MMM-yyyy') + '\n';

        if (d.ClosedDate != null) {
            output += '   Closed:     ' + d.ClosedDate.format('dd-MMM-yyyy') + '\n';
        }

        output += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';

        return output;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }

    public class DisputeStatusRequest {
        @InvocableVariable(label='Customer Id' description='Verified Account Id of the customer' required=true)
        public String customerId;

        @InvocableVariable(label='Case Number' description='Optional — provide to get expanded details for a specific dispute case. Leave blank to get the numbered list of all disputes.' required=false)
        public String caseNumber;
    }

    public class DisputeStatusResult {
        @InvocableVariable(label='Success' description='Whether dispute status was retrieved successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message')
        public String message;

        @InvocableVariable(label='Status Summary' description='Formatted dispute status — either a numbered list or expanded detail')
        public String statusSummary;

        @InvocableVariable(label='Dispute Count' description='Number of dispute cases found')
        public Integer disputeCount;
    }
}