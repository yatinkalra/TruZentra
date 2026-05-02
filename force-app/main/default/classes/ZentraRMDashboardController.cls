/**
 * ZentraRMDashboardController
 * @description Apex controller for the TruZentraOps Operations Console LWC.
 *              Provides account search and comprehensive customer data retrieval
 *              for the Customer 360 dashboard.
 * @author      BlueForce Team
 * @date        2026-04-21
 */
public without sharing class ZentraRMDashboardController {

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }
        String likeKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        return [
            SELECT Id, Name, Phone, PersonEmail,
                   (SELECT Id, FirstName, LastName, Email, Phone FROM Contacts LIMIT 1)
            FROM Account
            WHERE Name LIKE :likeKey
               OR Phone LIKE :likeKey
               OR PersonMobilePhone LIKE :likeKey
               OR PersonEmail LIKE :likeKey
            ORDER BY Name
            LIMIT 10
        ];
    }

    @AuraEnabled
    public static DashboardData getDashboardData(Id accountId) {
        DashboardData data = new DashboardData();

        // ── Account ──
        data.account = [
            SELECT Id, Name, Phone, CreatedDate
            FROM Account WHERE Id = :accountId LIMIT 1
        ];

        // ── Primary Contact ──
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, Phone
            FROM Contact WHERE AccountId = :accountId ORDER BY CreatedDate LIMIT 1
        ];
        data.primaryContact = contacts.isEmpty() ? null : contacts[0];

        // ── Financial Accounts ──
        data.financialAccounts = [
            SELECT Id, Name, FinServ__FinancialAccountType__c, FinServ__Balance__c,
                   FinServ__Status__c, Account_Number_Masked__c,
                   FinServ__TotalCreditLimit__c, FinServ__AvailableCredit__c,
                   FinServ__PrincipalBalance__c, FinServ__LoanTermMonths__c,
                   FinServ__InterestRate__c, FinServ__LoanAmount__c,
                   FinServ__LoanEndDate__c, FinServ__OpenDate__c,
                   Current_EMI__c, Is_Restructured__c, Last_Restructure_Date__c,
                   FinServ__BranchName__c
            FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :accountId
            ORDER BY FinServ__FinancialAccountType__c
        ];

        Set<Id> faIds = new Set<Id>();
        for (FinServ__FinancialAccount__c fa : data.financialAccounts) {
            faIds.add(fa.Id);
        }

        // ── Cards ──
        data.cards = faIds.isEmpty() ? new List<FinServ__Card__c>() : [
            SELECT Id, Name, FinServ__Active__c, FinServ__ValidUntil__c,
                   FinServ__FinancialAccount__c, FinServ__FinancialAccount__r.Name
            FROM FinServ__Card__c
            WHERE FinServ__FinancialAccount__c IN :faIds
            ORDER BY FinServ__ValidUntil__c DESC
        ];

        // ── Recent Transactions (last 20) ──
        data.recentTransactions = faIds.isEmpty() ? new List<FinServ__FinancialAccountTransaction__c>() : [
            SELECT Id, Name, FinServ__TransactionDate__c, FinServ__Amount__c,
                   FinServ__Description__c, Merchant_Name__c, Category__c,
                   FinServ__FinancialAccount__c, FinServ__FinancialAccount__r.Name
            FROM FinServ__FinancialAccountTransaction__c
            WHERE FinServ__FinancialAccount__c IN :faIds
            ORDER BY FinServ__TransactionDate__c DESC
            LIMIT 20
        ];

        // ── Loan Restructuring Requests ──
        data.loanRestructuringRequests = [
            SELECT Id, Name, Status__c, Selected_Option__c,
                   Original_EMI__c, New_EMI__c, New_Tenure_Months__c,
                   Additional_Interest__c, Monthly_Savings__c,
                   RM_Callback_Scheduled__c, CreatedDate,
                   Loan_Financial_Account__c, Loan_Financial_Account__r.Name
            FROM Loan_Restructuring_Request__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
        ];

        // ── Recurring Payments ──
        data.recurringPayments = [
            SELECT Id, Name, Payee_Name__c, Amount__c, Frequency__c,
                   Status__c, Start_Date__c, End_Date__c,
                   Next_Payment_Date__c, Last_Payment_Date__c,
                   Payment_Purpose__c, Remarks__c,
                   Source_Account__c, Source_Account__r.Name
            FROM Zentra_Recurring_Payment__c
            WHERE Customer__c = :accountId
            ORDER BY Status__c, Next_Payment_Date__c
        ];

        // ── Dispute Cases ──
        data.disputeCases = [
            SELECT Id, CaseNumber, Subject, Status, Dispute_Amount__c,
                   Dispute_Stage__c, Provisional_Credit_Issued__c,
                   Provisional_Credit_Amount__c, Estimated_Resolution_Date__c,
                   CreatedDate, Disputed_Transaction__r.Name
            FROM Case
            WHERE AccountId = :accountId
              AND RecordType.DeveloperName IN ('Dispute', 'New_Account_Opening')
            ORDER BY CreatedDate DESC
        ];

        // ── Holdings (Mutual Funds / SIPs) ──
        data.sipRecords = [
            SELECT Id, Name, Fund_Name__c, Folio_Number__c, SIP_Amount__c,
                   Frequency__c, SIP_Day__c, Status__c, Start_Date__c, End_Date__c,
                   FinServ__Shares__c, Total_Invested__c, FinServ__MarketValue__c,
                   Installments_Completed__c, Next_Installment_Date__c, Remarks__c,
                   Source_Account__c, Source_Account__r.Name
            FROM FinServ__FinancialHolding__c
            WHERE FinServ__PrimaryOwner__c = :accountId
            ORDER BY Status__c, Next_Installment_Date__c
        ];

        // ── OTP Sessions (last 10) ──
        data.recentOTPSessions = [
            SELECT Id, Name, Phone_Number__c, Status__c,
                   Attempt_Count__c, Expires_At__c, Channel__c, CreatedDate
            FROM Zentra_OTP_Session__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        // ── Email Logs (last 15) ──
        data.recentEmailLogs = [
            SELECT Id, Name, Email_Type__c, Recipient_Email__c,
                   Subject__c, Status__c, Error_Message__c, CreatedDate
            FROM Zentra_Email_Log__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 15
        ];

        // ── Error Logs (last 10) ──
        data.recentErrorLogs = [
            SELECT Id, Name, Source_Class__c, Method__c,
                   Error_Message__c, Severity__c, CreatedDate
            FROM Zentra_Error_Log__c
            WHERE Customer__c = :accountId
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        return data;
    }

    // ── Freeze / Reactivate Financial Account ──
    @AuraEnabled
    public static void freezeFinancialAccount(Id financialAccountId) {
        update new FinServ__FinancialAccount__c(Id = financialAccountId, FinServ__Status__c = 'Inactive');
    }

    @AuraEnabled
    public static void reactivateFinancialAccount(Id financialAccountId) {
        update new FinServ__FinancialAccount__c(Id = financialAccountId, FinServ__Status__c = 'Active');
    }

    // ── Freeze / Reactivate Card ──
    @AuraEnabled
    public static void freezeCard(Id cardId) {
        update new FinServ__Card__c(Id = cardId, FinServ__Active__c = false);
    }

    @AuraEnabled
    public static void reactivateCard(Id cardId) {
        update new FinServ__Card__c(Id = cardId, FinServ__Active__c = true);
    }

    // ── Stop Recurring Payment ──
    @AuraEnabled
    public static void stopRecurringPayment(Id paymentId) {
        update new Zentra_Recurring_Payment__c(Id = paymentId, Status__c = 'Cancelled');
    }

    // ── Global Deactivate All Savings & Cards ──
    @AuraEnabled
    public static void deactivateAllAccountsAndCards(Id accountId) {
        List<FinServ__FinancialAccount__c> fas = [
            SELECT Id, FinServ__Status__c, FinServ__FinancialAccountType__c
            FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :accountId
              AND FinServ__Status__c = 'Active'
              AND FinServ__FinancialAccountType__c IN ('Savings Account', 'Credit Card')
        ];
        for (FinServ__FinancialAccount__c fa : fas) {
            fa.FinServ__Status__c = 'Inactive';
        }
        if (!fas.isEmpty()) { update fas; }

        List<FinServ__Card__c> cards = [
            SELECT Id, FinServ__Active__c
            FROM FinServ__Card__c
            WHERE FinServ__AccountHolder__c = :accountId
              AND FinServ__Active__c = true
        ];
        for (FinServ__Card__c c : cards) {
            c.FinServ__Active__c = false;
        }
        if (!cards.isEmpty()) { update cards; }
    }

    // ── Global Reactivate All Savings & Cards ──
    @AuraEnabled
    public static void reactivateAllAccountsAndCards(Id accountId) {
        List<FinServ__FinancialAccount__c> fas = [
            SELECT Id, FinServ__Status__c, FinServ__FinancialAccountType__c
            FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :accountId
              AND FinServ__Status__c != 'Active'
              AND FinServ__FinancialAccountType__c IN ('Savings Account', 'Credit Card')
        ];
        for (FinServ__FinancialAccount__c fa : fas) {
            fa.FinServ__Status__c = 'Active';
        }
        if (!fas.isEmpty()) { update fas; }

        List<FinServ__Card__c> cards = [
            SELECT Id, FinServ__Active__c
            FROM FinServ__Card__c
            WHERE FinServ__AccountHolder__c = :accountId
              AND FinServ__Active__c = false
        ];
        for (FinServ__Card__c c : cards) {
            c.FinServ__Active__c = true;
        }
        if (!cards.isEmpty()) { update cards; }
    }

    // ── File Transaction Dispute ──
    @AuraEnabled
    public static Id fileTransactionDispute(Id transactionId, Id accountId, String disputeType, String description) {
        FinServ__FinancialAccountTransaction__c txn = [
            SELECT Id, Name, FinServ__Amount__c, FinServ__Description__c, Merchant_Name__c,
                   FinServ__TransactionDate__c,
                   FinServ__FinancialAccount__c,
                   FinServ__FinancialAccount__r.Name,
                   FinServ__FinancialAccount__r.FinServ__FinancialAccountNumber__c,
                   FinServ__FinancialAccount__r.FinServ__FinancialAccountType__c,
                   FinServ__FinancialAccount__r.FinServ__PrimaryOwner__r.Name
            FROM FinServ__FinancialAccountTransaction__c
            WHERE Id = :transactionId LIMIT 1
        ];

        Id rtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Dispute').getRecordTypeId();
        String merchant = txn.Merchant_Name__c != null ? txn.Merchant_Name__c : txn.FinServ__Description__c;
        String acctName = txn.FinServ__FinancialAccount__r?.FinServ__PrimaryOwner__r?.Name;
        String faName = txn.FinServ__FinancialAccount__r?.Name;
        String faNumber = txn.FinServ__FinancialAccount__r?.FinServ__FinancialAccountNumber__c;
        String faType = txn.FinServ__FinancialAccount__r?.FinServ__FinancialAccountType__c;

        String fullDesc = 'Dispute Type: ' + disputeType + '\n'
            + 'Source: RM Dashboard\n\n'
            + '── Account Details ──\n'
            + 'Account Name: ' + (acctName != null ? acctName : '—') + '\n'
            + 'Financial Account: ' + (faName != null ? faName : '—') + '\n'
            + 'Account Number: ' + (faNumber != null ? faNumber : '—') + '\n'
            + 'Account Type: ' + (faType != null ? faType : '—') + '\n\n'
            + '── Transaction Details ──\n'
            + 'Transaction ID: ' + txn.Name + '\n'
            + 'Merchant: ' + (merchant != null ? merchant : '—') + '\n'
            + 'Amount: ₹' + txn.FinServ__Amount__c + '\n'
            + 'Date: ' + (txn.FinServ__TransactionDate__c != null ? String.valueOf(txn.FinServ__TransactionDate__c) : '—') + '\n\n'
            + '── Provisional Credit ──\n'
            + 'Credit Amount: ₹' + txn.FinServ__Amount__c + '\n'
            + 'Credit Issued: Yes (Automatic)\n\n'
            + (String.isNotBlank(description) ? '── Additional Details ──\n' + description : '');

        Case dispute = new Case(
            AccountId = accountId,
            RecordTypeId = rtId,
            Subject = disputeType + ' — ' + merchant,
            Status = 'New',
            Disputed_Transaction__c = transactionId,
            Dispute_Amount__c = txn.FinServ__Amount__c,
            Dispute_Stage__c = 'Filed',
            Provisional_Credit_Issued__c = true,
            Provisional_Credit_Amount__c = txn.FinServ__Amount__c,
            Description = fullDesc,
            Estimated_Resolution_Date__c = Date.today().addDays(10)
        );
        insert dispute;
        return dispute.Id;
    }

    public class DashboardData {
        @AuraEnabled public Account account;
        @AuraEnabled public Contact primaryContact;
        @AuraEnabled public List<FinServ__FinancialAccount__c> financialAccounts;
        @AuraEnabled public List<FinServ__Card__c> cards;
        @AuraEnabled public List<FinServ__FinancialAccountTransaction__c> recentTransactions;
        @AuraEnabled public List<Loan_Restructuring_Request__c> loanRestructuringRequests;
        @AuraEnabled public List<Zentra_Recurring_Payment__c> recurringPayments;
        @AuraEnabled public List<Case> disputeCases;
        @AuraEnabled public List<Zentra_OTP_Session__c> recentOTPSessions;
        @AuraEnabled public List<Zentra_Email_Log__c> recentEmailLogs;
        @AuraEnabled public List<Zentra_Error_Log__c> recentErrorLogs;
        @AuraEnabled public List<FinServ__FinancialHolding__c> sipRecords;
    }
}