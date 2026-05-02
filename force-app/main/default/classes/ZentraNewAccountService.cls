/**
 * ZentraNewAccountService - Creates a Case for new account opening when a
 * prospect's phone number is not found in the system.
 * Creates a Case (Record Type: New_Account_Opening) and schedules an RM
 * callback within 4 hours.
 * @author  BlueForce Team
 * @date    2026-04-18
 */
public without sharing class ZentraNewAccountService {

    public class NewAccountRequest {
        @InvocableVariable(label='Phone Number' description='Prospect phone number' required=true)
        public String phoneNumber;

        @InvocableVariable(label='Customer Name' description='Full name of the prospect. Always ask the prospect for their full name.' required=true)
        public String customerName;

        @InvocableVariable(label='Customer Email' description='Email address of the prospect. Always ask the prospect for their email — it is required for account creation and welcome confirmation.' required=true)
        public String customerEmail;
    }

    public class NewAccountResult {
        @InvocableVariable(label='Success' description='Whether the request was created successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='User-facing response message')
        public String message;

        @InvocableVariable(label='Case Number' description='Auto-generated Case Number')
        public String caseNumber;

        @InvocableVariable(label='RM Callback Time' description='Scheduled RM callback datetime')
        public String rmCallbackTime;
    }

    @InvocableMethod(label='Request New Account Opening'
        description='Creates a New Account Opening Case and schedules an RM callback within 4 hours. Always collect the prospect full name, email, and phone before calling this action.'
        category='Account Opening')
    public static List<NewAccountResult> requestNewAccount(List<NewAccountRequest> requests) {
        List<NewAccountResult> results = new List<NewAccountResult>();

        Id newAcctRT;
        try {
            newAcctRT = Schema.SObjectType.Case
                .getRecordTypeInfosByDeveloperName().get('New_Account_Opening').getRecordTypeId();
        } catch (Exception e) {
            ZentraErrorLogger.log('ZentraNewAccountService', 'requestNewAccount', e);
            NewAccountResult errResult = new NewAccountResult();
            errResult.success = false;
            errResult.message = 'New Account Opening record type not configured. Please contact support.';
            results.add(errResult);
            return results;
        }

        List<Case> casesToInsert = new List<Case>();
        List<Integer> indexMap = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            NewAccountRequest req = requests[i];
            NewAccountResult r = new NewAccountResult();

            if (String.isBlank(req.phoneNumber)) {
                r.success = false;
                r.message = 'Phone number is required to create a new account request.';
                results.add(r);
                continue;
            }

            if (String.isBlank(req.customerName)) {
                r.success = false;
                r.message = 'Customer name is required to create a new account request.';
                results.add(r);
                continue;
            }
            if (String.isBlank(req.customerEmail)) {
                r.success = false;
                r.message = 'Customer email is required to create a new account request.';
                results.add(r);
                continue;
            }

            String custName = req.customerName;
            DateTime rmCallback = DateTime.now().addHours(4);

            Case c = new Case(
                RecordTypeId = newAcctRT,
                Subject = 'New Account Opening Request — ' + custName,
                Description = 'A new prospect contacted TruZentra (WhatsApp) and requested to open a bank account.\n\n'
                    + 'Name: ' + custName + '\n'
                    + 'Phone: ' + req.phoneNumber + '\n'
                    + 'Email: ' + req.customerEmail + '\n'
                    + 'RM Callback Scheduled: ' + rmCallback.format('dd MMM yyyy, hh:mm a') + '\n\n'
                    + 'Please contact the prospect within 4 hours to initiate the account opening process.',
                Origin = 'Web',
                Priority = 'High',
                Status = 'New',
                SuppliedPhone = req.phoneNumber,
                SuppliedName = custName,
                SuppliedEmail = req.customerEmail,
                RM_Callback_Scheduled__c = rmCallback
            );

            casesToInsert.add(c);
            indexMap.add(i);

            r.success = true;
            r.rmCallbackTime = rmCallback.format('dd MMM yyyy, hh:mm a');
            results.add(r);
        }

        if (!casesToInsert.isEmpty()) {
            try {
                insert casesToInsert;
                for (Integer j = 0; j < casesToInsert.size(); j++) {
                    Integer origIdx = indexMap[j];
                    NewAccountResult r = results[origIdx];
                    // Re-query for auto-number CaseNumber
                    Case inserted = [SELECT CaseNumber FROM Case WHERE Id = :casesToInsert[j].Id LIMIT 1];
                    r.caseNumber = inserted.CaseNumber;
                    r.message = 'Your new account request has been created successfully (Ref: ' + inserted.CaseNumber
                        + '). A Relationship Manager will call you at ' + r.rmCallbackTime + ' to assist with the account opening.';

                    // Send welcome confirmation email to the prospect
                    NewAccountRequest origReq = requests[origIdx];
                    if (String.isNotBlank(origReq.customerEmail)) {
                        try {
                            ZentraEmailService.sendNewAccountWelcomeEmail(
                                origReq.customerEmail,
                                origReq.customerName,
                                inserted.CaseNumber,
                                r.rmCallbackTime,
                                origReq.phoneNumber
                            );
                        } catch (Exception emailEx) {
                            ZentraErrorLogger.log('ZentraNewAccountService', 'requestNewAccount-email', emailEx);
                        }
                    }
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraNewAccountService', 'requestNewAccount', e);
                for (Integer j = 0; j < indexMap.size(); j++) {
                    Integer origIdx = indexMap[j];
                    NewAccountResult r = results[origIdx];
                    r.success = false;
                    r.message = 'Unable to create your request at this time. Please try again later or visit your nearest branch.';
                }
            }
        }

        return results;
    }
}