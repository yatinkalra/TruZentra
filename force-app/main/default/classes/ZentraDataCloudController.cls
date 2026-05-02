/**
 * ZentraDataCloudController
 * @description Apex controller for the Zentra Data Cloud Dashboard LWC.
 *              Queries Data Cloud DMO (__dll) objects to provide a unified
 *              customer 360 view sourced entirely from Data Cloud.
 *              Uses dynamic SOQL because __dll types may not compile in static SOQL.
 * @author      BlueForce Team
 * @date        2026-04-26
 */
public with sharing class ZentraDataCloudController {

    // ── Account Search ──
    // NOTE: LIKE on Data Cloud __dll objects is case-sensitive.
    //       We fetch broadly and filter in Apex for case-insensitive matching.
    @AuraEnabled(cacheable=true)
    public static List<AccountInfo> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<AccountInfo>();
        }
        String lowerTerm = searchTerm.trim().toLowerCase();
        String q = 'SELECT Id__c, Name__c, Phone__c, PersonEmail__c, PersonMobilePhone__c'
            + ' FROM Zentra_Account__dll LIMIT 200';
        List<AccountInfo> mapped = new List<AccountInfo>();
        for (SObject r : Database.query(q)) {
            String name   = str(r, 'Name__c');
            String phone  = str(r, 'Phone__c');
            String email  = str(r, 'PersonEmail__c');
            String mobile = str(r, 'PersonMobilePhone__c');
            Boolean match = (name   != null && name.toLowerCase().contains(lowerTerm))
                         || (phone  != null && phone.contains(lowerTerm))
                         || (email  != null && email.toLowerCase().contains(lowerTerm))
                         || (mobile != null && mobile.contains(lowerTerm));
            if (match) {
                AccountInfo ai = new AccountInfo();
                ai.Id = str(r, 'Id__c');
                ai.Name = name;
                ai.Phone = phone;
                ai.PersonEmail = email;
                ai.PersonMobilePhone = mobile;
                mapped.add(ai);
                if (mapped.size() >= 10) break;
            }
        }
        return mapped;
    }

    // ── Dashboard Data ──
    @AuraEnabled
    public static DashboardData getDashboardData(String accountId) {
        DashboardData data = new DashboardData();
        String safeId = String.escapeSingleQuotes(accountId);

        // ── Account ──
        String qAcct = 'SELECT Id__c, Name__c, Phone__c, PersonEmail__c, PersonMobilePhone__c, CreatedDate__c'
            + ' FROM Zentra_Account__dll'
            + ' WHERE Id__c = \'' + safeId + '\' LIMIT 1';
        List<SObject> accounts = Database.query(qAcct);
        if (!accounts.isEmpty()) {
            SObject a = accounts[0];
            data.account = new AccountInfo();
            data.account.Id = str(a, 'Id__c');
            data.account.Name = str(a, 'Name__c');
            data.account.Phone = str(a, 'Phone__c');
            data.account.PersonEmail = str(a, 'PersonEmail__c');
            data.account.PersonMobilePhone = str(a, 'PersonMobilePhone__c');
            data.account.CreatedDate = (Datetime) a.get('CreatedDate__c');
        }

        // ── Financial Accounts ──
        data.financialAccounts = new List<FinancialAccountInfo>();
        Set<String> faIds = new Set<String>();
        String qFA = 'SELECT Id__c, Name__c, FinServ_FinancialAccountType_c__c, FinServ_Balance_c__c,'
            + ' FinServ_Status_c__c, Account_Number_Masked_c__c,'
            + ' FinServ_TotalCreditLimit_c__c, FinServ_AvailableCredit_c__c,'
            + ' FinServ_PrincipalBalance_c__c, FinServ_LoanTermMonths_c__c,'
            + ' FinServ_InterestRate_c__c, FinServ_LoanAmount_c__c,'
            + ' FinServ_LoanEndDate_c__c, FinServ_OpenDate_c__c,'
            + ' Current_EMI_c__c, Is_Restructured_c__c, Last_Restructure_Date_c__c,'
            + ' FinServ_BranchName_c__c'
            + ' FROM Zentra_CRM_FinancialAccount__dll'
            + ' WHERE FinServ_PrimaryOwner_c__c = \'' + safeId + '\'';
        for (SObject fa : Database.query(qFA)) {
            String faId = str(fa, 'Id__c');
            faIds.add(faId);
            FinancialAccountInfo fi = new FinancialAccountInfo();
            fi.Id = faId;
            fi.Name = str(fa, 'Name__c');
            fi.FinancialAccountType = str(fa, 'FinServ_FinancialAccountType_c__c');
            fi.Balance = dec(fa, 'FinServ_Balance_c__c');
            fi.Status = str(fa, 'FinServ_Status_c__c');
            fi.AccountNumberMasked = str(fa, 'Account_Number_Masked_c__c');
            fi.TotalCreditLimit = dec(fa, 'FinServ_TotalCreditLimit_c__c');
            fi.AvailableCredit = dec(fa, 'FinServ_AvailableCredit_c__c');
            fi.PrincipalBalance = dec(fa, 'FinServ_PrincipalBalance_c__c');
            fi.LoanTermMonths = dec(fa, 'FinServ_LoanTermMonths_c__c');
            fi.InterestRate = dec(fa, 'FinServ_InterestRate_c__c');
            fi.LoanAmount = dec(fa, 'FinServ_LoanAmount_c__c');
            fi.LoanEndDate = dt(fa, 'FinServ_LoanEndDate_c__c');
            fi.OpenDate = dt(fa, 'FinServ_OpenDate_c__c');
            fi.CurrentEMI = dec(fa, 'Current_EMI_c__c');
            fi.IsRestructured = (Boolean) fa.get('Is_Restructured_c__c');
            fi.LastRestructureDate = dt(fa, 'Last_Restructure_Date_c__c');
            fi.BranchName = str(fa, 'FinServ_BranchName_c__c');
            data.financialAccounts.add(fi);
        }

        // ── Recent Transactions ──
        data.recentTransactions = new List<TransactionInfo>();
        if (!faIds.isEmpty()) {
            String inClause = buildInClause(faIds);
            String qTxn = 'SELECT Id__c, Name__c, FinServ_TransactionDate_c__c, FinServ_Amount_c__c,'
                + ' FinServ_Description_c__c, Merchant_Name_c__c, Category_c__c,'
                + ' FinServ_FinancialAccount_c__c'
                + ' FROM Zentra_CRM_Transaction__dll'
                + ' WHERE FinServ_FinancialAccount_c__c IN (' + inClause + ')'
                + ' LIMIT 50';
            for (SObject t : Database.query(qTxn)) {
                TransactionInfo ti = new TransactionInfo();
                ti.Id = str(t, 'Id__c');
                ti.Name = str(t, 'Name__c');
                ti.TransactionDate = (Datetime) t.get('FinServ_TransactionDate_c__c');
                ti.Amount = dec(t, 'FinServ_Amount_c__c');
                ti.Description = str(t, 'FinServ_Description_c__c');
                ti.MerchantName = str(t, 'Merchant_Name_c__c');
                ti.Category = str(t, 'Category_c__c');
                ti.FinancialAccountId = str(t, 'FinServ_FinancialAccount_c__c');
                data.recentTransactions.add(ti);
            }
        }

        // ── Recurring Payments ──
        data.recurringPayments = new List<RecurringPaymentInfo>();
        String qRP = 'SELECT Id__c, Name__c, Payee_Name_c__c, Amount_c__c, Frequency_c__c,'
            + ' Status_c__c, Start_Date_c__c, End_Date_c__c,'
            + ' Next_Payment_Date_c__c, Last_Payment_Date_c__c,'
            + ' Payment_Purpose_c__c, Remarks_c__c'
            + ' FROM Zentra_CRM_RecurringPayment__dll'
            + ' WHERE Customer_c__c = \'' + safeId + '\'';
        for (SObject rp : Database.query(qRP)) {
            RecurringPaymentInfo ri = new RecurringPaymentInfo();
            ri.Id = str(rp, 'Id__c');
            ri.Name = str(rp, 'Name__c');
            ri.PayeeName = str(rp, 'Payee_Name_c__c');
            ri.Amount = dec(rp, 'Amount_c__c');
            ri.Frequency = str(rp, 'Frequency_c__c');
            ri.Status = str(rp, 'Status_c__c');
            ri.StartDate = dt(rp, 'Start_Date_c__c');
            ri.EndDate = dt(rp, 'End_Date_c__c');
            ri.NextPaymentDate = dt(rp, 'Next_Payment_Date_c__c');
            ri.LastPaymentDate = dt(rp, 'Last_Payment_Date_c__c');
            ri.PaymentPurpose = str(rp, 'Payment_Purpose_c__c');
            ri.Remarks = str(rp, 'Remarks_c__c');
            data.recurringPayments.add(ri);
        }

        // ── Loan Restructuring Requests ──
        data.loanRestructuringRequests = new List<LoanRequestInfo>();
        String qLoan = 'SELECT Id__c, Name__c, Status_c__c, Selected_Option_c__c,'
            + ' Original_EMI_c__c, New_EMI_c__c, New_Tenure_Months_c__c,'
            + ' Additional_Interest_c__c, Monthly_Savings_c__c,'
            + ' RM_Callback_Scheduled_c__c, CreatedDate__c'
            + ' FROM Zentra_CRM_LoanRestructure__dll'
            + ' WHERE Customer_c__c = \'' + safeId + '\'';
        for (SObject l : Database.query(qLoan)) {
            LoanRequestInfo li = new LoanRequestInfo();
            li.Id = str(l, 'Id__c');
            li.Name = str(l, 'Name__c');
            li.Status = str(l, 'Status_c__c');
            li.SelectedOption = str(l, 'Selected_Option_c__c');
            li.OriginalEMI = dec(l, 'Original_EMI_c__c');
            li.NewEMI = dec(l, 'New_EMI_c__c');
            li.NewTenureMonths = dec(l, 'New_Tenure_Months_c__c');
            li.AdditionalInterest = dec(l, 'Additional_Interest_c__c');
            li.MonthlySavings = dec(l, 'Monthly_Savings_c__c');
            li.RMCallbackScheduled = (Datetime) l.get('RM_Callback_Scheduled_c__c');
            li.CreatedDate = (Datetime) l.get('CreatedDate__c');
            data.loanRestructuringRequests.add(li);
        }

        // ── Dispute Cases ──
        data.disputeCases = new List<DisputeCaseInfo>();
        String qCase = 'SELECT Id__c, CaseNumber__c, Subject__c, Status__c,'
            + ' Dispute_Amount_c__c, Dispute_Stage_c__c,'
            + ' Provisional_Credit_Issued_c__c, Provisional_Credit_Amount_c__c,'
            + ' Estimated_Resolution_Date_c__c, CreatedDate__c'
            + ' FROM Zentra_CRM_Case__dll'
            + ' WHERE AccountId__c = \'' + safeId + '\'';
        for (SObject c : Database.query(qCase)) {
            DisputeCaseInfo di = new DisputeCaseInfo();
            di.Id = str(c, 'Id__c');
            di.CaseNumber = str(c, 'CaseNumber__c');
            di.Subject = str(c, 'Subject__c');
            di.Status = str(c, 'Status__c');
            di.DisputeAmount = dec(c, 'Dispute_Amount_c__c');
            di.DisputeStage = str(c, 'Dispute_Stage_c__c');
            di.ProvisionalCreditIssued = (Boolean) c.get('Provisional_Credit_Issued_c__c');
            di.ProvisionalCreditAmount = dec(c, 'Provisional_Credit_Amount_c__c');
            di.EstimatedResolutionDate = dt(c, 'Estimated_Resolution_Date_c__c');
            di.CreatedDate = (Datetime) c.get('CreatedDate__c');
            data.disputeCases.add(di);
        }

        return data;
    }

    // ── Calculated Insight: Churn Risk ──
    @AuraEnabled
    public static ChurnInsight getChurnInsight(String accountId) {
        String safeId = String.escapeSingleQuotes(accountId);
        try {
            ConnectApi.CdpQueryInput qi = new ConnectApi.CdpQueryInput();
            qi.sql = 'SELECT customer_id__c, first_name__c, last_name__c,'
                + ' total_accounts__c, active_accounts__c,'
                + ' stopped_payments__c, active_payments__c,'
                + ' open_disputes__c, txn_count__c, churn_risk_score__c'
                + ' FROM Zentra_Customer_Churn_Risk__cio'
                + ' WHERE customer_id__c = \'' + safeId + '\'';
            ConnectApi.CdpQueryOutputV2 out = ConnectApi.CdpQuery.queryAnsiSqlV2(qi);
            if (out.data != null && !out.data.isEmpty()) {
                // CdpQueryV2Row cannot be cast directly; use JSON round-trip
                List<List<String>> rows = (List<List<String>>) JSON.deserialize(
                    JSON.serialize(out.data), List<List<String>>.class
                );
                if (!rows.isEmpty()) {
                    List<String> row = rows[0];
                    // Column order matches SELECT: 0=customer_id, 1=first_name, 2=last_name,
                    // 3=total_accounts, 4=active_accounts, 5=stopped_payments, 6=active_payments,
                    // 7=open_disputes, 8=txn_count, 9=churn_risk_score
                    ChurnInsight ci = new ChurnInsight();
                    ci.customerId = strVal(row, 0);
                    ci.totalAccounts = numVal(row, 3);
                    ci.activeAccounts = numVal(row, 4);
                    ci.stoppedPayments = numVal(row, 5);
                    ci.activePayments = numVal(row, 6);
                    ci.openDisputes = numVal(row, 7);
                    ci.txnCount = numVal(row, 8);
                    ci.churnRiskScore = numVal(row, 9);
                    ci.available = true;
                    return ci;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Churn CI query failed: ' + e.getMessage());
        }
        ChurnInsight empty = new ChurnInsight();
        empty.available = false;
        return empty;
    }

    private static String strVal(List<String> row, Integer idx) {
        return row.size() > idx && String.isNotBlank(row[idx]) ? row[idx] : null;
    }
    private static Integer numVal(List<String> row, Integer idx) {
        if (row.size() <= idx || String.isBlank(row[idx])) return 0;
        return Decimal.valueOf(row[idx]).intValue();
    }

    // ═══ Helpers ═══
    private static String str(SObject r, String f) { return (String) r.get(f); }
    private static Decimal dec(SObject r, String f) { return (Decimal) r.get(f); }
    private static Date dt(SObject r, String f) { return (Date) r.get(f); }

    private static String buildInClause(Set<String> ids) {
        List<String> parts = new List<String>();
        for (String i : ids) { parts.add('\'' + String.escapeSingleQuotes(i) + '\''); }
        return String.join(parts, ',');
    }

    // ═══════════════════════════════════════════════
    //  Wrapper Classes
    // ═══════════════════════════════════════════════

    public class DashboardData {
        @AuraEnabled public AccountInfo account;
        @AuraEnabled public List<FinancialAccountInfo> financialAccounts;
        @AuraEnabled public List<TransactionInfo> recentTransactions;
        @AuraEnabled public List<RecurringPaymentInfo> recurringPayments;
        @AuraEnabled public List<LoanRequestInfo> loanRestructuringRequests;
        @AuraEnabled public List<DisputeCaseInfo> disputeCases;
    }

    public class AccountInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Phone;
        @AuraEnabled public String PersonEmail;
        @AuraEnabled public String PersonMobilePhone;
        @AuraEnabled public Datetime CreatedDate;
    }

    public class FinancialAccountInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String FinancialAccountType;
        @AuraEnabled public Decimal Balance;
        @AuraEnabled public String Status;
        @AuraEnabled public String AccountNumberMasked;
        @AuraEnabled public Decimal TotalCreditLimit;
        @AuraEnabled public Decimal AvailableCredit;
        @AuraEnabled public Decimal PrincipalBalance;
        @AuraEnabled public Decimal LoanTermMonths;
        @AuraEnabled public Decimal InterestRate;
        @AuraEnabled public Decimal LoanAmount;
        @AuraEnabled public Date LoanEndDate;
        @AuraEnabled public Date OpenDate;
        @AuraEnabled public Decimal CurrentEMI;
        @AuraEnabled public Boolean IsRestructured;
        @AuraEnabled public Date LastRestructureDate;
        @AuraEnabled public String BranchName;
    }

    public class TransactionInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Datetime TransactionDate;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String Description;
        @AuraEnabled public String MerchantName;
        @AuraEnabled public String Category;
        @AuraEnabled public String FinancialAccountId;
    }

    public class RecurringPaymentInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String PayeeName;
        @AuraEnabled public Decimal Amount;
        @AuraEnabled public String Frequency;
        @AuraEnabled public String Status;
        @AuraEnabled public Date StartDate;
        @AuraEnabled public Date EndDate;
        @AuraEnabled public Date NextPaymentDate;
        @AuraEnabled public Date LastPaymentDate;
        @AuraEnabled public String PaymentPurpose;
        @AuraEnabled public String Remarks;
    }

    public class LoanRequestInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Status;
        @AuraEnabled public String SelectedOption;
        @AuraEnabled public Decimal OriginalEMI;
        @AuraEnabled public Decimal NewEMI;
        @AuraEnabled public Decimal NewTenureMonths;
        @AuraEnabled public Decimal AdditionalInterest;
        @AuraEnabled public Decimal MonthlySavings;
        @AuraEnabled public Datetime RMCallbackScheduled;
        @AuraEnabled public Datetime CreatedDate;
    }

    public class DisputeCaseInfo {
        @AuraEnabled public String Id;
        @AuraEnabled public String CaseNumber;
        @AuraEnabled public String Subject;
        @AuraEnabled public String Status;
        @AuraEnabled public Decimal DisputeAmount;
        @AuraEnabled public String DisputeStage;
        @AuraEnabled public Boolean ProvisionalCreditIssued;
        @AuraEnabled public Decimal ProvisionalCreditAmount;
        @AuraEnabled public Date EstimatedResolutionDate;
        @AuraEnabled public Datetime CreatedDate;
    }

    public class ChurnInsight {
        @AuraEnabled public Boolean available;
        @AuraEnabled public String customerId;
        @AuraEnabled public Integer totalAccounts;
        @AuraEnabled public Integer activeAccounts;
        @AuraEnabled public Integer stoppedPayments;
        @AuraEnabled public Integer activePayments;
        @AuraEnabled public Integer openDisputes;
        @AuraEnabled public Integer txnCount;
        @AuraEnabled public Integer churnRiskScore;
    }
}
