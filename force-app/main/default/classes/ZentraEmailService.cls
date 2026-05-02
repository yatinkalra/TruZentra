/**
 * ZentraEmailService - Shared utility for sending branded confirmation emails.
 * Uses the same Contact email lookup pattern as ZentraOTPService.
 * Sends emails via OrgWideEmailAddress when available.
 * All configurable text (subject, heading, intro) and branding (colors, bank name)
 * are driven by Zentra_Email_Config__mdt custom metadata records.
 * @author  BlueForce Team
 * @date    2026-04-16
 */
public without sharing class ZentraEmailService {

    // ─── Metadata-driven configuration ───
    private static final String DEFAULT_BRAND  = '#1a237e';
    private static final String DEFAULT_ACCENT = '#4caf50';
    private static final String DEFAULT_BANK   = 'Zentra Bank';

    @TestVisible
    private static Map<String, Zentra_Email_Config__mdt> configCache;

    private static Map<String, Zentra_Email_Config__mdt> getConfigMap() {
        if (configCache != null) {
            return configCache;
        }
        configCache = new Map<String, Zentra_Email_Config__mdt>();
        for (Zentra_Email_Config__mdt cfg : [
            SELECT DeveloperName, Is_Enabled__c, Subject_Template__c,
                   Heading__c, Intro_Text__c, Brand_Color__c, Accent_Color__c, Bank_Name__c
            FROM Zentra_Email_Config__mdt
        ]) {
            configCache.put(cfg.DeveloperName, cfg);
        }
        return configCache;
    }

    private static Zentra_Email_Config__mdt getMaster() {
        return getConfigMap().get('Master');
    }

    private static Zentra_Email_Config__mdt getTypeConfig(String devName) {
        return getConfigMap().get(devName);
    }

    private static String brandColor() {
        Zentra_Email_Config__mdt m = getMaster();
        return (m != null && String.isNotBlank(m.Brand_Color__c)) ? m.Brand_Color__c : DEFAULT_BRAND;
    }

    private static String accentColor() {
        Zentra_Email_Config__mdt m = getMaster();
        return (m != null && String.isNotBlank(m.Accent_Color__c)) ? m.Accent_Color__c : DEFAULT_ACCENT;
    }

    private static String bankName() {
        Zentra_Email_Config__mdt m = getMaster();
        return (m != null && String.isNotBlank(m.Bank_Name__c)) ? m.Bank_Name__c : DEFAULT_BANK;
    }

    /**
     * Returns false if Master or the specific email type is disabled.
     */
    public static Boolean isEnabled(String devName) {
        Zentra_Email_Config__mdt m = getMaster();
        if (m != null && m.Is_Enabled__c == false) {
            return false;
        }
        Zentra_Email_Config__mdt t = getTypeConfig(devName);
        if (t != null && t.Is_Enabled__c == false) {
            return false;
        }
        return true;
    }

    /**
     * Resolves subject from metadata template using String.format merge tokens.
     * Falls back to provided defaultSubject if no metadata found.
     */
    private static String resolveSubject(String devName, String defaultSubject, List<String> mergeValues) {
        Zentra_Email_Config__mdt cfg = getTypeConfig(devName);
        if (cfg != null && String.isNotBlank(cfg.Subject_Template__c)) {
            List<String> vals = new List<String>{ bankName() };
            if (mergeValues != null) {
                vals.addAll(mergeValues);
            }
            return String.format(cfg.Subject_Template__c, vals);
        }
        return defaultSubject;
    }

    private static String resolveHeading(String devName, String defaultHeading) {
        Zentra_Email_Config__mdt cfg = getTypeConfig(devName);
        return (cfg != null && String.isNotBlank(cfg.Heading__c)) ? cfg.Heading__c : defaultHeading;
    }

    private static String resolveIntro(String devName, String defaultIntro, List<String> mergeValues) {
        Zentra_Email_Config__mdt cfg = getTypeConfig(devName);
        if (cfg != null && String.isNotBlank(cfg.Intro_Text__c)) {
            return (mergeValues != null && !mergeValues.isEmpty())
                ? String.format(cfg.Intro_Text__c, mergeValues)
                : cfg.Intro_Text__c;
        }
        return defaultIntro;
    }

    /**
     * Sends a dispute confirmation email to the customer's Contact email.
     */
    public static Boolean sendDisputeConfirmationEmail(Id accountId, String caseNumber, Decimal disputeAmount,
                                                     String merchantName, String estimatedResolution) {
        if (!isEnabled('Dispute_Confirmation')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Dispute Confirmation', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();
        String heading = resolveHeading('Dispute_Confirmation', 'Dispute Filed Successfully');
        String intro = resolveIntro('Dispute_Confirmation',
            'We have received your dispute and our team is already working on it. Here are the details for your reference:', null);

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Case Number', caseNumber)
            + tableRow('Dispute Amount', '&#8377;' + formatCurrency(disputeAmount))
            + tableRow('Transaction', merchantName != null ? merchantName : 'N/A')
            + tableRow('Provisional Credit', '&#8377;' + formatCurrency(disputeAmount) + ' (credited to your account)')
            + tableRow('Expected Resolution', estimatedResolution)
            + '</table>'
            + '<div style="background-color:#e8f5e9;border-left:4px solid ' + accentColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:#2e7d32;font-size:14px;"><strong>&#10004; Provisional Credit Issued</strong><br/>'
            + 'A provisional credit of &#8377;' + formatCurrency(disputeAmount) + ' has been applied to your account while we investigate.</p>'
            + '</div>'
            + '<p style="color:#333;font-size:14px;line-height:1.6;">As per RBI guidelines, we will resolve this within <strong>7 working days</strong>. '
            + 'You can check the status anytime by chatting with TruZentra.</p>'
        );

        String subject = resolveSubject('Dispute_Confirmation',
            bankName() + ' \u2014 Dispute Confirmation (Case #' + caseNumber + ')',
            new List<String>{ caseNumber });
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Dispute Confirmation', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a loan restructuring confirmation email to the customer's Contact email.
     */
    public static Boolean sendLoanRestructuringEmail(Id accountId, String requestNumber, String loanType,
                                                   String optionLabel, Decimal originalEMI, Decimal newEMI,
                                                   Integer newTenure, Decimal monthlySavings) {
        if (!isEnabled('Loan_Confirmation')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Loan Restructuring', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();
        String heading = resolveHeading('Loan_Confirmation', 'Loan Restructuring Confirmed');
        String intro = resolveIntro('Loan_Confirmation',
            'Your loan restructuring request has been submitted successfully. Here are the details:', null);

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Request Number', requestNumber)
            + tableRow('Loan Type', loanType)
            + tableRow('Selected Option', optionLabel)
            + tableRow('Previous EMI', '&#8377;' + formatCurrency(originalEMI) + '/month')
            + tableRow('New EMI', '&#8377;' + formatCurrency(newEMI) + '/month')
            + tableRow('New Tenure', String.valueOf(newTenure) + ' months')
            + tableRow('Monthly Savings', '&#8377;' + formatCurrency(monthlySavings))
            + '</table>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;"><strong>&#128222; RM Callback Scheduled</strong><br/>'
            + 'A Relationship Manager will contact you within <strong>24 hours</strong> to finalize the restructuring and answer any questions.</p>'
            + '</div>'
            + '<p style="color:#333;font-size:14px;line-height:1.6;">The new EMI will be effective from your next billing cycle. '
            + 'If you have any questions, simply chat with TruZentra anytime.</p>'
        );

        String subject = resolveSubject('Loan_Confirmation',
            bankName() + ' \u2014 Loan Restructuring Confirmation (' + requestNumber + ')',
            new List<String>{ requestNumber });
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Loan Restructuring', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a balance summary email to the customer's Contact email.
     */
    public static Boolean sendBalanceSummaryEmail(Id accountId) {
        if (!isEnabled('Balance_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Balance Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        // Query all active financial accounts
        List<FinServ__FinancialAccount__c> accounts = [
            SELECT FinServ__FinancialAccountType__c, FinServ__Balance__c,
                   FinServ__TotalCreditLimit__c, FinServ__AvailableCredit__c, Name
            FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :accountId
              AND FinServ__Status__c = 'Active'
            ORDER BY FinServ__FinancialAccountType__c ASC
        ];

        if (accounts.isEmpty()) {
            logEmailAudit(accountId, 'Balance Summary', con.Email, null, 'No Data', 'No active financial accounts found');
            return false;
        }

        String rows = '';
        for (FinServ__FinancialAccount__c a : accounts) {
            String acctType = a.FinServ__FinancialAccountType__c != null ? a.FinServ__FinancialAccountType__c : 'Account';
            Decimal bal = a.FinServ__Balance__c != null ? a.FinServ__Balance__c : 0;
            rows += tableRow(acctType, '&#8377;' + formatCurrency(bal));
            if (acctType.containsIgnoreCase('Credit') || acctType.containsIgnoreCase('Card')) {
                if (a.FinServ__TotalCreditLimit__c != null) {
                    rows += tableRow('  \u2514 Credit Limit', '&#8377;' + formatCurrency(a.FinServ__TotalCreditLimit__c));
                }
                if (a.FinServ__AvailableCredit__c != null) {
                    rows += tableRow('  \u2514 Available Credit', '&#8377;' + formatCurrency(a.FinServ__AvailableCredit__c));
                }
            }
        }

        String nowStr = DateTime.now().format('dd MMM yyyy, hh:mm a');
        String heading = resolveHeading('Balance_Summary', 'Account Balance Summary');
        String intro = resolveIntro('Balance_Summary',
            'Here is your latest account balance summary as of <strong>' + nowStr + '</strong>:',
            new List<String>{ nowStr });

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + rows
            + '</table>'
            + '<p style="color:#555;font-size:13px;margin-top:15px;">Total accounts: <strong>' + accounts.size() + '</strong></p>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">You can check your balance anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Balance_Summary',
            bankName() + ' \u2014 Your Account Balance Summary', null);
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Balance Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a transaction summary (mini-statement) email to the customer's Contact email.
     */
    public static Boolean sendTransactionSummaryEmail(Id accountId) {
        if (!isEnabled('Transaction_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Transaction Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        List<FinServ__FinancialAccountTransaction__c> txns = [
            SELECT FinServ__TransactionDate__c,
                   FinServ__Amount__c,
                   FinServ__Description__c,
                   FinServ__TransactionType__c,
                   FinServ__FinancialAccount__r.Name,
                   FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c
            FROM FinServ__FinancialAccountTransaction__c
            WHERE FinServ__FinancialAccount__r.FinServ__PrimaryOwner__c = :accountId
              AND FinServ__FinancialAccount__r.FinServ__Status__c = 'Active'
            ORDER BY FinServ__TransactionDate__c DESC
            LIMIT 20
        ];

        if (txns.isEmpty()) {
            logEmailAudit(accountId, 'Transaction Summary', con.Email, null, 'No Data', 'No recent transactions found');
            return false;
        }

        // Build transaction rows
        String txnRows = '';
        for (FinServ__FinancialAccountTransaction__c t : txns) {
            String dateStr = t.FinServ__TransactionDate__c != null ? t.FinServ__TransactionDate__c.format() : '\u2014';
            String txnDesc = t.FinServ__Description__c != null ? t.FinServ__Description__c : 'Unknown';
            Decimal amt = t.FinServ__Amount__c != null ? t.FinServ__Amount__c : 0;
            String txnType = t.FinServ__TransactionType__c != null ? t.FinServ__TransactionType__c : '';
            Boolean isCredit = txnType.equalsIgnoreCase('Credit');
            String amtColor = isCredit ? '#2e7d32' : '#c62828';
            String sign = isCredit ? '+' : '-';
            String acctName = (t.FinServ__FinancialAccount__r != null && t.FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c != null)
                ? t.FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c
                : '';

            txnRows += '<tr>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#666;font-size:13px;">' + dateStr + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;">' + txnDesc + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#888;font-size:12px;">' + acctName + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;font-size:13px;font-weight:bold;color:' + amtColor + ';text-align:right;">'
                + sign + '&#8377;' + formatCurrency(amt) + '</td>'
                + '</tr>';
        }

        String nowStr = DateTime.now().format('dd MMM yyyy, hh:mm a');
        String heading = resolveHeading('Transaction_Summary', 'Transaction Summary');
        String intro = resolveIntro('Transaction_Summary',
            'Here are your last <strong>' + txns.size() + '</strong> transactions as of <strong>' + nowStr + '</strong>:',
            new List<String>{ String.valueOf(txns.size()), nowStr });

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + '<tr style="background-color:#f5f5f5;">'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Date</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Description</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Account</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Amount</th>'
            + '</tr>'
            + txnRows
            + '</table>'
            + '<p style="color:#555;font-size:13px;margin-top:15px;">Showing last <strong>' + txns.size() + '</strong> transactions across all active accounts.</p>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">You can view your transactions anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Transaction_Summary',
            bankName() + ' \u2014 Your Transaction Summary', null);
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Transaction Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a dispute SUMMARY email (not a confirmation).
     * Used by the Email Summary agent action — framed as "here's a summary of your dispute".
     */
    public static Boolean sendDisputeSummaryEmail(Id accountId, String caseNumber, String disputeStage,
                                                  Decimal disputeAmount, String merchantName,
                                                  String estimatedResolution, Boolean provCreditIssued,
                                                  Decimal provCreditAmount, Datetime filedDate) {
        if (!isEnabled('Dispute_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Dispute Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        String filedDateStr = filedDate != null ? filedDate.format('dd MMM yyyy, hh:mm a') : '\u2014';
        String stageDisplay = String.isNotBlank(disputeStage) ? disputeStage : 'Filed';
        String provCreditRow = '';
        if (provCreditIssued == true && provCreditAmount != null) {
            provCreditRow = tableRow('Provisional Credit', '&#8377;' + formatCurrency(provCreditAmount) + ' (credited)');
        } else {
            provCreditRow = tableRow('Provisional Credit', 'Not yet issued');
        }

        String heading = resolveHeading('Dispute_Summary', 'Your Dispute Summary');
        String intro = resolveIntro('Dispute_Summary',
            'Here is the latest summary of your dispute case for your records:', null);

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Case Number', caseNumber)
            + tableRow('Status', stageDisplay)
            + tableRow('Dispute Amount', '&#8377;' + formatCurrency(disputeAmount))
            + tableRow('Transaction', merchantName != null ? merchantName : 'N/A')
            + provCreditRow
            + tableRow('Filed On', filedDateStr)
            + tableRow('Expected Resolution', estimatedResolution)
            + '</table>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">You can check the latest status of your dispute anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Dispute_Summary',
            bankName() + ' \u2014 Dispute Summary (Case #' + caseNumber + ')',
            new List<String>{ caseNumber });
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Dispute Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a loan restructuring SUMMARY email (not a confirmation).
     * Used by the Email Summary agent action — framed as "here's a summary of your restructuring".
     */
    public static Boolean sendLoanRestructuringSummaryEmail(Id accountId, String requestNumber, String status,
                                                           String loanType, String optionLabel,
                                                           Decimal originalEMI, Decimal newEMI,
                                                           Integer newTenure, Decimal monthlySavings) {
        if (!isEnabled('Loan_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Loan Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        String statusDisplay = String.isNotBlank(status) ? status : 'Submitted';
        String heading = resolveHeading('Loan_Summary', 'Your Loan Restructuring Summary');
        String intro = resolveIntro('Loan_Summary',
            'Here is the latest summary of your loan restructuring request for your records:', null);

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Request Number', requestNumber)
            + tableRow('Status', statusDisplay)
            + tableRow('Loan Type', loanType)
            + tableRow('Selected Option', optionLabel)
            + tableRow('Previous EMI', '&#8377;' + formatCurrency(originalEMI) + '/month')
            + tableRow('New EMI', '&#8377;' + formatCurrency(newEMI) + '/month')
            + tableRow('New Tenure', String.valueOf(newTenure) + ' months')
            + tableRow('Monthly Savings', '&#8377;' + formatCurrency(monthlySavings))
            + '</table>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">The new EMI will be effective from your next billing cycle. '
            + 'You can check your restructuring status anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Loan_Summary',
            bankName() + ' \u2014 Loan Restructuring Summary (' + requestNumber + ')',
            new List<String>{ requestNumber });
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Loan Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a recurring payment (standing instructions) SUMMARY email to the customer's Contact email.
     * Used by the Email Summary agent action.
     */
    public static Boolean sendRecurringPaymentSummaryEmail(Id accountId) {
        if (!isEnabled('Recurring_Payment_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Recurring Payment Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        List<Zentra_Recurring_Payment__c> payments = [
            SELECT Payee_Name__c, Amount__c, Frequency__c, Next_Payment_Date__c,
                   End_Date__c, Status__c, Payment_Purpose__c,
                   Source_Account__r.Name, Source_Account__r.FinServ__FinancialAccountType__c
            FROM Zentra_Recurring_Payment__c
            WHERE Customer__c = :accountId
              AND Status__c = 'Active'
            ORDER BY Next_Payment_Date__c ASC NULLS LAST
            LIMIT 50
        ];

        if (payments.isEmpty()) {
            logEmailAudit(accountId, 'Recurring Payment Summary', con.Email, null, 'No Data', 'No active recurring payments found');
            return false;
        }

        String rows = '';
        for (Zentra_Recurring_Payment__c p : payments) {
            String payee = p.Payee_Name__c != null ? p.Payee_Name__c : '\u2014';
            Decimal amt = p.Amount__c != null ? p.Amount__c : 0;
            String freq = p.Frequency__c != null ? p.Frequency__c : '\u2014';
            String nextDt = p.Next_Payment_Date__c != null ? p.Next_Payment_Date__c.format() : '\u2014';
            String endDt = p.End_Date__c != null ? p.End_Date__c.format() : 'Indefinite';
            String purpose = p.Payment_Purpose__c != null ? p.Payment_Purpose__c : '';
            String sourceAcct = '';
            if (p.Source_Account__r != null && p.Source_Account__r.Name != null) {
                sourceAcct = p.Source_Account__r.Name;
            }

            rows += '<tr>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;">' + payee + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;font-weight:bold;text-align:right;">&#8377;' + formatCurrency(amt) + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#666;font-size:13px;">' + freq + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;">' + nextDt + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#888;font-size:13px;">' + endDt + '</td>'
                + '</tr>';
        }

        String nowStr = DateTime.now().format('dd MMM yyyy, hh:mm a');
        String heading = resolveHeading('Recurring_Payment_Summary', 'Your Recurring Payments Summary');
        String intro = resolveIntro('Recurring_Payment_Summary',
            'Here is a summary of your active standing instructions as of <strong>' + nowStr + '</strong>:',
            new List<String>{ nowStr });

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + '<tr style="background-color:#f5f5f5;">'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Payee</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Amount</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Frequency</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Next Payment</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Valid Until</th>'
            + '</tr>'
            + rows
            + '</table>'
            + '<p style="color:#555;font-size:13px;margin-top:15px;">Total active instructions: <strong>' + payments.size() + '</strong></p>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">You can view or manage your recurring payments anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Recurring_Payment_Summary',
            bankName() + ' \u2014 Your Recurring Payments Summary', null);
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Recurring Payment Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a mutual fund / SIP portfolio SUMMARY email to the customer's Contact email.
     * Used by the Email Summary agent action.
     */
    public static Boolean sendMutualFundSummaryEmail(Id accountId) {
        if (!isEnabled('Mutual_Fund_Summary')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Mutual Fund Summary', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();

        List<FinServ__FinancialHolding__c> sips = [
            SELECT Fund_Name__c, Folio_Number__c, SIP_Amount__c, Frequency__c,
                   Status__c, Total_Invested__c, FinServ__MarketValue__c,
                   Next_Installment_Date__c
            FROM FinServ__FinancialHolding__c
            WHERE FinServ__PrimaryOwner__c = :accountId
              AND Status__c = 'Active'
            ORDER BY FinServ__MarketValue__c DESC NULLS LAST
            LIMIT 50
        ];

        if (sips.isEmpty()) {
            logEmailAudit(accountId, 'Mutual Fund Summary', con.Email, null, 'No Data', 'No active SIPs found');
            return false;
        }

        Decimal totalInvested = 0;
        Decimal totalValue = 0;
        String rows = '';

        for (FinServ__FinancialHolding__c s : sips) {
            String fund = s.Fund_Name__c != null ? s.Fund_Name__c : '\u2014';
            Decimal invested = s.Total_Invested__c != null ? s.Total_Invested__c : 0;
            Decimal curVal = s.FinServ__MarketValue__c != null ? s.FinServ__MarketValue__c : 0;
            Decimal gain = curVal - invested;
            String gainColor = gain >= 0 ? '#2e7d32' : '#c62828';
            String gainPrefix = gain >= 0 ? '+' : '';
            String sipAmt = s.SIP_Amount__c != null ? '&#8377;' + formatCurrency(s.SIP_Amount__c) : '\u2014';
            String nextDt = s.Next_Installment_Date__c != null ? s.Next_Installment_Date__c.format() : '\u2014';

            rows += '<tr>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;">' + fund + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;text-align:right;">' + sipAmt + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;text-align:right;font-weight:bold;">&#8377;' + formatCurrency(invested) + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;text-align:right;font-weight:bold;">&#8377;' + formatCurrency(curVal) + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;font-size:13px;text-align:right;color:' + gainColor + ';font-weight:bold;">' + gainPrefix + '&#8377;' + formatCurrency(gain.abs()) + '</td>'
                + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:13px;">' + nextDt + '</td>'
                + '</tr>';

            totalInvested += invested;
            totalValue += curVal;
        }

        Decimal totalGain = totalValue - totalInvested;
        Decimal returnPct = totalInvested > 0 ? ((totalGain / totalInvested) * 100).setScale(1) : 0;
        String totalGainColor = totalGain >= 0 ? '#2e7d32' : '#c62828';

        String nowStr = DateTime.now().format('dd MMM yyyy, hh:mm a');
        String heading = resolveHeading('Mutual_Fund_Summary', 'Your Mutual Fund / SIP Portfolio');
        String intro = resolveIntro('Mutual_Fund_Summary',
            'Here is a summary of your active SIP investments as of <strong>' + nowStr + '</strong>:',
            new List<String>{ nowStr });

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + '<tr style="background-color:#f5f5f5;">'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Fund Name</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">SIP</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Invested</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Value</th>'
            + '<th style="padding:10px 12px;text-align:right;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Gain/Loss</th>'
            + '<th style="padding:10px 12px;text-align:left;font-size:12px;color:#666;border-bottom:2px solid #ddd;">Next SIP</th>'
            + '</tr>'
            + rows
            + '</table>'
            + '<div style="background-color:#f5f5f5;border-radius:6px;padding:15px;margin:15px 0;">'
            + '<table style="width:100%;border-collapse:collapse;">'
            + '<tr><td style="padding:5px 0;color:#666;font-size:14px;">Total Invested</td><td style="padding:5px 0;text-align:right;font-size:14px;font-weight:bold;">&#8377;' + formatCurrency(totalInvested) + '</td></tr>'
            + '<tr><td style="padding:5px 0;color:#666;font-size:14px;">Current Value</td><td style="padding:5px 0;text-align:right;font-size:14px;font-weight:bold;">&#8377;' + formatCurrency(totalValue) + '</td></tr>'
            + '<tr><td style="padding:5px 0;color:#666;font-size:14px;">Overall Returns</td><td style="padding:5px 0;text-align:right;font-size:14px;font-weight:bold;color:' + totalGainColor + ';">' + (totalGain >= 0 ? '+' : '-') + '&#8377;' + formatCurrency(totalGain.abs()) + ' (' + returnPct + '%)</td></tr>'
            + '</table></div>'
            + '<p style="color:#555;font-size:13px;margin-top:15px;">Active SIPs: <strong>' + sips.size() + '</strong></p>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;">You can view your mutual fund portfolio anytime by chatting with <strong>TruZentra</strong> on WhatsApp.</p>'
            + '</div>'
        );

        String subject = resolveSubject('Mutual_Fund_Summary',
            bankName() + ' \u2014 Your Mutual Fund / SIP Portfolio Summary', null);
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Mutual Fund Summary', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    // ─── Private Helpers ───

    private static Contact getContactWithEmail(Id accountId) {
        try {
            List<Contact> contacts = [
                SELECT Id, Email, FirstName, AccountId
                FROM Contact
                WHERE AccountId = :accountId AND Email != null
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            return contacts.isEmpty() ? null : contacts[0];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ZentraEmailService: Contact lookup failed — ' + e.getMessage());
            return null;
        }
    }

    private static Id getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
        if (owea.isEmpty()) {
            owea = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        }
        return owea.isEmpty() ? null : owea[0].Id;
    }

    private static String sendEmail(String toAddress, String subject, String htmlBody, Id orgWideEmailId) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ toAddress });
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setSaveAsActivity(false);
            if (orgWideEmailId != null) {
                email.setOrgWideEmailAddressId(orgWideEmailId);
            }
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email }, false);
            if (results != null && !results.isEmpty() && results[0].isSuccess()) {
                return null;
            }
            String errMsg = '';
            if (results != null && !results.isEmpty()) {
                for (Messaging.SendEmailError err : results[0].getErrors()) {
                    errMsg += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                }
            }
            System.debug(LoggingLevel.ERROR, 'ZentraEmailService: Email send failed — ' + errMsg);
            return errMsg;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ZentraEmailService: Email send exception — ' + e.getMessage());
            return e.getMessage();
        }
    }

    public static void logEmailAudit(Id accountId, String emailType, String recipientEmail, String subject, String status, String errorMsg) {
        try {
            Zentra_Email_Log__c log = new Zentra_Email_Log__c(
                Customer__c = accountId,
                Email_Type__c = emailType,
                Recipient_Email__c = recipientEmail,
                Subject__c = subject,
                Status__c = status,
                Error_Message__c = errorMsg
            );
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ZentraEmailService: Audit log failed — ' + e.getMessage());
        }
    }

    /**
     * Sends a recurring payment CANCELLATION confirmation email to the customer's Contact email.
     * Called after a standing instruction is stopped via ZentraStopRecurringPaymentService.
     */
    public static Boolean sendRecurringPaymentCancelledEmail(Id accountId, String payeeName,
                                                              Decimal amount, String frequency,
                                                              String referenceNumber) {
        if (!isEnabled('Recurring_Payment_Cancelled')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'Recurring Payment Cancelled', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();
        String heading = resolveHeading('Recurring_Payment_Cancelled', 'Standing Instruction Cancelled');
        String intro = resolveIntro('Recurring_Payment_Cancelled',
            'Your standing instruction has been successfully cancelled. No further debits will be made for this instruction. Here are the details:', null);

        String safePayee = String.isNotBlank(payeeName) ? payeeName : 'N/A';
        String safeAmount = amount != null ? '&#8377;' + formatCurrency(amount) : 'N/A';
        String safeFreq = String.isNotBlank(frequency) ? frequency : 'N/A';
        String safeRef = String.isNotBlank(referenceNumber) ? referenceNumber : 'N/A';
        String cancelledOn = DateTime.now().format('dd MMM yyyy, hh:mm a');

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Payee', safePayee)
            + tableRow('Amount', safeAmount)
            + tableRow('Frequency', safeFreq)
            + tableRow('Reference', safeRef)
            + tableRow('Cancelled On', cancelledOn)
            + tableRow('Status', '<span style="color:#c62828;font-weight:bold;">Cancelled</span>')
            + '</table>'
            + '<div style="background-color:#ffebee;border-left:4px solid #c62828;padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:#c62828;font-size:14px;"><strong>&#10060; Payment Stopped</strong><br/>'
            + 'This standing instruction has been permanently cancelled. No future debits will be processed for this instruction.</p>'
            + '</div>'
            + '<p style="color:#333;font-size:14px;line-height:1.6;">If you did not request this cancellation or need to set up a new standing instruction, '
            + 'please contact your branch or chat with <strong>TruZentra</strong> on WhatsApp.</p>'
        );

        String subject = resolveSubject('Recurring_Payment_Cancelled',
            bankName() + ' \u2014 Standing Instruction Cancelled (' + safeRef + ')',
            new List<String>{ safeRef });
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'Recurring Payment Cancelled', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends a welcome / thank-you email to a new prospect who requested account opening.
     * Unlike other methods, this does NOT require an Account/Contact — it sends directly
     * to the prospect-provided email address.
     */
    public static Boolean sendNewAccountWelcomeEmail(String prospectEmail, String prospectName,
                                                     String caseNumber, String rmCallbackTime, String phoneNumber) {
        if (!isEnabled('New_Account_Welcome')) { return false; }
        if (String.isBlank(prospectEmail)) { return false; }

        String firstName = String.isNotBlank(prospectName) ? prospectName : 'Future Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();
        String heading = resolveHeading('New_Account_Welcome', 'Thank You for Choosing ' + bankName() + '!');
        String intro = resolveIntro('New_Account_Welcome',
            'We are thrilled that you have shown interest in opening an account with us! '
            + 'Your request has been received and a dedicated Relationship Manager will be calling you shortly to guide you through the process.', null);

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Reference Number', caseNumber)
            + tableRow('Phone Number', phoneNumber)
            + tableRow('RM Callback By', rmCallbackTime)
            + '</table>'
            + '<div style="background-color:#e3f2fd;border-left:4px solid ' + brandColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:' + brandColor() + ';font-size:14px;"><strong>&#128222; What Happens Next?</strong><br/>'
            + 'A Relationship Manager from ' + bankName() + ' will call you within <strong>4 hours</strong> at the phone number you provided. '
            + 'They will guide you through the documentation and account opening process.</p>'
            + '</div>'
            + '<div style="background-color:#e8f5e9;border-left:4px solid ' + accentColor() + ';padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:#2e7d32;font-size:14px;"><strong>&#128203; Please Keep Ready</strong></p>'
            + '<ul style="color:#555;font-size:13px;margin:8px 0 0 0;padding-left:18px;">'
            + '<li>Aadhaar Card / PAN Card</li>'
            + '<li>Address Proof (Utility Bill / Passport)</li>'
            + '<li>Recent Passport-size Photograph</li>'
            + '</ul></div>'
            + '<p style="color:#333;font-size:14px;line-height:1.6;">We look forward to welcoming you to the ' + bankName() + ' family! '
            + 'If you have any questions in the meantime, feel free to chat with <strong>TruZentra</strong> on WhatsApp.</p>'
        );

        String subject = resolveSubject('New_Account_Welcome',
            bankName() + ' \u2014 Welcome! Your Account Opening Request (Ref: ' + caseNumber + ')',
            new List<String>{ caseNumber });
        String sendError = sendEmail(prospectEmail, subject, htmlBody, orgWideEmailId);
        logEmailAudit(null, 'New Account Welcome', prospectEmail, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    /**
     * Sends an MPIN login success notification email to the customer's Contact email.
     * Called after successful OTP/MPIN verification in TruZentra.
     */
    public static Boolean sendMpinLoginEmail(Id accountId) {
        if (!isEnabled('MPIN_Login')) { return false; }
        Contact con = getContactWithEmail(accountId);
        if (con == null) {
            logEmailAudit(accountId, 'MPIN Login', null, null, 'No Contact', null);
            return false;
        }

        String firstName = String.isNotBlank(con.FirstName) ? con.FirstName : 'Valued Customer';
        Id orgWideEmailId = getOrgWideEmailAddressId();
        String nowStr = DateTime.now().format('dd MMM yyyy, hh:mm a');
        String heading = resolveHeading('MPIN_Login', 'Login Alert — MPIN Authentication');
        String intro = resolveIntro('MPIN_Login',
            'A successful login to your account was detected via <strong>MPIN</strong> on <strong>' + nowStr + '</strong>.',
            new List<String>{ nowStr });

        String htmlBody = buildEmailWrapper(firstName,
            '<h2 style="color:' + brandColor() + ';margin:0 0 10px 0;font-size:22px;">' + heading + '</h2>'
            + '<p style="color:#333;font-size:15px;line-height:1.6;">' + intro + '</p>'
            + '<table style="width:100%;border-collapse:collapse;margin:15px 0;">'
            + tableRow('Authentication Method', 'MPIN')
            + tableRow('Date & Time', nowStr)
            + tableRow('Channel', 'TruZentra (WhatsApp)')
            + tableRow('Status', '&#9989; Successful')
            + '</table>'
            + '<div style="background-color:#fff3e0;border-left:4px solid #ff9800;padding:12px 15px;margin:15px 0;border-radius:4px;">'
            + '<p style="margin:0;color:#e65100;font-size:14px;"><strong>&#9888; Not you?</strong><br/>'
            + 'If you did not initiate this login, please contact ' + bankName() + ' immediately through our customer care '
            + 'or chat with <strong>TruZentra</strong> on WhatsApp to secure your account.</p>'
            + '</div>'
        );

        String subject = resolveSubject('MPIN_Login',
            bankName() + ' \u2014 Login Alert: MPIN Authentication Successful', null);
        String sendError = sendEmail(con.Email, subject, htmlBody, orgWideEmailId);
        logEmailAudit(accountId, 'MPIN Login', con.Email, subject, sendError == null ? 'Sent' : 'Failed', sendError);
        return sendError == null;
    }

    private static String buildEmailWrapper(String firstName, String bodyContent) {
        String brand = brandColor();
        String bank = bankName();
        return '<html><body style="margin:0;padding:0;background-color:#f4f6f9;font-family:Arial,Helvetica,sans-serif;">'
            + '<table role="presentation" width="100%" style="background-color:#f4f6f9;padding:20px 0;"><tr><td align="center">'
            + '<table role="presentation" width="600" style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.08);">'

            // Header
            + '<tr><td style="background:linear-gradient(135deg,' + brand + ',#283593);padding:25px 30px;text-align:center;">'
            + '<h1 style="color:#ffffff;margin:0;font-size:26px;font-weight:700;letter-spacing:1px;">' + bank.toUpperCase() + '</h1>'
            + '<p style="color:#9fa8da;margin:5px 0 0 0;font-size:13px;letter-spacing:2px;">TRUSTED &amp; SECURE BANKING</p>'
            + '</td></tr>'

            // Body
            + '<tr><td style="padding:30px;">'
            + '<p style="color:#333;font-size:16px;margin:0 0 20px 0;">Dear <strong>' + firstName + '</strong>,</p>'
            + bodyContent
            + '</td></tr>'

            // Footer
            + '<tr><td style="background-color:#f5f5f5;padding:20px 30px;text-align:center;border-top:1px solid #e0e0e0;">'
            + '<p style="color:#666;font-size:12px;margin:0;">This is an automated message from ' + bank + '. Please do not reply to this email.</p>'
            + '<p style="color:#666;font-size:12px;margin:5px 0 0 0;">Need help? Chat with <strong>TruZentra</strong> on WhatsApp anytime.</p>'
            + '<p style="color:#999;font-size:11px;margin:8px 0 0 0;">&copy; 2026 ' + bank + '. All rights reserved.</p>'
            + '</td></tr>'

            + '</table></td></tr></table></body></html>';
    }

    private static String tableRow(String label, String value) {
        return '<tr>'
            + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#666;font-size:14px;width:40%;">' + label + '</td>'
            + '<td style="padding:8px 12px;border-bottom:1px solid #eee;color:#333;font-size:14px;font-weight:bold;">' + value + '</td>'
            + '</tr>';
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }
}