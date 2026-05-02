/**
 * ZentraBalanceService - Returns all financial account balances for an authenticated customer.
 * Queries FinServ__FinancialAccount__c (Savings, Credit Card, Loan).
 * @author  BlueForce Team
 * @date    2026-04-10
 */
public without sharing class ZentraBalanceService {

    @InvocableMethod(label='Get Account Balance'
        description='Returns all financial account balances for an authenticated customer. Supports Hindi and English output formatting.')
    public static List<BalanceResult> getBalance(List<BalanceRequest> requests) {
        List<BalanceResult> results = new List<BalanceResult>();
        for (BalanceRequest req : requests) {
            BalanceResult r = new BalanceResult();
            try {
                List<FinServ__FinancialAccount__c> accounts = [
                    SELECT FinServ__FinancialAccountType__c,
                           FinServ__Balance__c,
                           FinServ__TotalCreditLimit__c,
                           FinServ__AvailableCredit__c,
                           FinServ__Status__c,
                           FinServ__FinancialAccountNumber__c,
                           Account_Number_Masked__c,
                           FinServ__BranchName__c,
                           FinServ__PrincipalBalance__c,
                           FinServ__LoanAmount__c,
                           FinServ__InterestRate__c,
                           FinServ__LoanTermMonths__c,
                           Current_EMI__c,
                           Name
                    FROM FinServ__FinancialAccount__c
                    WHERE FinServ__PrimaryOwner__c = :req.customerId
                    ORDER BY FinServ__FinancialAccountType__c ASC
                ];

                if (accounts.isEmpty()) {
                    r.success = false;
                    r.balanceSummary = (req.language == 'hi')
                        ? 'कोई खाता नहीं मिला।'
                        : 'No financial accounts found.';
                    r.accountCount = 0;
                } else {
                    r.success = true;
                    r.balanceSummary = formatBalances(accounts, req.language);
                    r.accountCount = accounts.size();
                }
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraBalanceService', 'getBalance', e, req.customerId != null ? Id.valueOf(req.customerId) : null);
                r.success = false;
                r.balanceSummary = 'Error retrieving balance: ' + e.getMessage();
                r.accountCount = 0;
            }
            results.add(r);
        }
        return results;
    }

    private static String formatBalances(List<FinServ__FinancialAccount__c> accts, String lang) {
        Boolean isHindi = (lang == 'hi');

        Map<String, String> typeLabelsHi = new Map<String, String>{
            'Savings'         => 'बचत खाता',
            'Savings Account' => 'बचत खाता',
            'Checking'        => 'चालू खाता',
            'Checking Account'=> 'चालू खाता',
            'Credit Card'     => 'क्रेडिट कार्ड',
            'CreditCard'      => 'क्रेडिट कार्ड',
            'Loan Account'    => 'लोन खाता',
            'Auto Loan'       => 'ऑटो लोन',
            'Mortgage'        => 'होम लोन',
            'Home Loan'       => 'होम लोन',
            'HomeLoan'        => 'होम लोन',
            'Personal Loan'   => 'पर्सनल लोन',
            'Investment'      => 'निवेश',
            'Investment Account' => 'निवेश'
        };

        Map<String, String> typeLabelsEn = new Map<String, String>{
            'Savings'         => 'Savings Account',
            'Savings Account' => 'Savings Account',
            'Checking'        => 'Checking Account',
            'Checking Account'=> 'Checking Account',
            'Credit Card'     => 'Credit Card',
            'CreditCard'      => 'Credit Card',
            'Loan Account'    => 'Loan Account',
            'Auto Loan'       => 'Auto Loan',
            'Mortgage'        => 'Mortgage',
            'Home Loan'       => 'Home Loan',
            'HomeLoan'        => 'Home Loan',
            'Personal Loan'   => 'Personal Loan',
            'Investment'      => 'Investment',
            'Investment Account' => 'Investment'
        };

        Map<String, String> typeEmojis = new Map<String, String>{
            'Savings Account' => '💰',
            'Savings'         => '💰',
            'Checking'        => '💰',
            'Checking Account'=> '💰',
            'Credit Card'     => '💳',
            'CreditCard'      => '💳',
            'Loan Account'    => '🏦',
            'Auto Loan'       => '🚗',
            'Mortgage'        => '🏠',
            'Home Loan'       => '🏠',
            'HomeLoan'        => '🏠',
            'Personal Loan'   => '💼',
            'Investment'      => '📈',
            'Investment Account' => '📈'
        };

        Map<String, String> statusLabelsHi = new Map<String, String>{
            'Active'   => '✅ सक्रिय',
            'Inactive' => '🔴 निष्क्रिय',
            'Frozen'   => '🔒 फ्रोज़न',
            'Closed'   => '⛔ बंद'
        };
        Map<String, String> statusLabelsEn = new Map<String, String>{
            'Active'   => '✅ Active',
            'Inactive' => '🔴 Inactive',
            'Frozen'   => '🔒 Frozen',
            'Closed'   => '⛔ Closed'
        };

        Set<String> LOAN_TYPES = new Set<String>{'Loan Account', 'Auto Loan', 'Mortgage', 'Home Loan', 'HomeLoan', 'Personal Loan'};

        String output = isHindi
            ? '━━━━━━━━━━━━━━━━━━━━━━━━━━\n🏦 आपके खातों का विवरण\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n'
            : '━━━━━━━━━━━━━━━━━━━━━━━━━━\n🏦 Your Account Overview\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';

        for (Integer i = 0; i < accts.size(); i++) {
            FinServ__FinancialAccount__c a = accts[i];
            String acctType = a.FinServ__FinancialAccountType__c;
            Boolean isLoan = acctType != null && LOAN_TYPES.contains(acctType);
            String label = isHindi
                ? (typeLabelsHi.containsKey(acctType) ? typeLabelsHi.get(acctType) : acctType)
                : (typeLabelsEn.containsKey(acctType) ? typeLabelsEn.get(acctType) : acctType);
            String emoji = typeEmojis.containsKey(acctType) ? typeEmojis.get(acctType) : '📋';

            String status = a.FinServ__Status__c != null ? a.FinServ__Status__c : 'Unknown';
            String statusDisplay = isHindi
                ? (statusLabelsHi.containsKey(status) ? statusLabelsHi.get(status) : status)
                : (statusLabelsEn.containsKey(status) ? statusLabelsEn.get(status) : status);

            output += emoji + ' ' + label + '  [' + statusDisplay + ']\n';

            String acctNum = a.Account_Number_Masked__c != null ? a.Account_Number_Masked__c : a.Name;
            String acctNumLabel = isHindi ? '   खाता' : '   Account';
            output += acctNumLabel + ':  ' + acctNum + '\n';

            if (isLoan) {
                Decimal principal = a.FinServ__PrincipalBalance__c != null ? a.FinServ__PrincipalBalance__c : (a.FinServ__LoanAmount__c != null ? a.FinServ__LoanAmount__c : 0);
                String outstandingLabel = isHindi ? '   बकाया राशि' : '   Outstanding';
                output += outstandingLabel + ':  ₹' + principal.format() + '\n';
                if (a.Current_EMI__c != null) {
                    String emiLabel = isHindi ? '   मासिक EMI' : '   EMI';
                    output += emiLabel + ':  ₹' + a.Current_EMI__c.format() + '\n';
                }
                if (a.FinServ__InterestRate__c != null) {
                    String rateLabel = isHindi ? '   ब्याज दर' : '   Interest Rate';
                    output += rateLabel + ':  ' + a.FinServ__InterestRate__c + '%\n';
                }
                if (a.FinServ__LoanTermMonths__c != null) {
                    String tenureLabel = isHindi ? '   अवधि' : '   Tenure';
                    output += tenureLabel + ':  ' + a.FinServ__LoanTermMonths__c.intValue() + (isHindi ? ' महीने' : ' months') + '\n';
                }
            } else {
                Decimal bal = (a.FinServ__Balance__c != null) ? a.FinServ__Balance__c : 0;
                String balLabel = isHindi ? '   शेष राशि' : '   Balance';
                output += balLabel + ':  ₹' + bal.format() + '\n';
            }

            if (acctType != null && (acctType.containsIgnoreCase('Credit') || acctType.containsIgnoreCase('Card'))) {
                if (a.FinServ__TotalCreditLimit__c != null) {
                    String limitLabel = isHindi ? '   क्रेडिट सीमा' : '   Credit Limit';
                    output += limitLabel + ':  ₹' + a.FinServ__TotalCreditLimit__c.format() + '\n';
                }
                if (a.FinServ__AvailableCredit__c != null) {
                    String availLabel = isHindi ? '   उपलब्ध क्रेडिट' : '   Available';
                    output += availLabel + ':  ₹' + a.FinServ__AvailableCredit__c.format() + '\n';
                }
            }

            if (a.FinServ__BranchName__c != null) {
                String branchLabel = isHindi ? '   शाखा' : '   Branch';
                output += branchLabel + ':  ' + a.FinServ__BranchName__c + '\n';
            }

            if (i < accts.size() - 1) {
                output += '──────────────────────────\n';
            }
        }

        output += '\n━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        output += isHindi
            ? '✅ ' + accts.size() + ' खाते मिले\n'
            : '✅ ' + accts.size() + ' account(s) found\n';

        return output;
    }

    public class BalanceRequest {
        @InvocableVariable(required=true description='The Account Id of the authenticated customer.')
        public Id customerId;

        @InvocableVariable(description='Language code: hi for Hindi, en for English. Defaults to en.')
        public String language;
    }

    public class BalanceResult {
        @InvocableVariable(description='Whether the balance query was successful.')
        public Boolean success;

        @InvocableVariable(description='Formatted balance summary string ready for display to the customer.')
        public String balanceSummary;

        @InvocableVariable(description='Number of active financial accounts found.')
        public Integer accountCount;
    }
}