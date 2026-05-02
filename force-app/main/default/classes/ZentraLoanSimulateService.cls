/**
 * ZentraLoanSimulateService
 * @description Simulates 3 loan restructuring options.
 *              Option A: Extend tenure by 12 months (lower EMI)
 *              Option B: Extend tenure by 24 months (even lower EMI)
 *              Option C: 3-month moratorium (interest-only, then resume)
 *              EMI Formula: P × r × (1+r)^n / ((1+r)^n - 1)
 * @developer   BlueForce Team
 * @date        2026-04-16
 */
public without sharing class ZentraLoanSimulateService {

    @InvocableMethod(label='Simulate Loan Restructuring'
        description='Calculates 3 restructuring options for a loan: extend 12 months, extend 24 months, or 3-month moratorium. Returns formatted comparison.'
        category='Loan Services')
    public static List<SimulateResult> simulate(List<SimulateRequest> requests) {
        List<SimulateResult> results = new List<SimulateResult>();

        for (SimulateRequest req : requests) {
            SimulateResult r = new SimulateResult();
            try {
                if (req.loanAccountId == null) {
                    r.success = false;
                    r.message = 'Loan Account Id is required.';
                    results.add(r);
                    continue;
                }

                FinServ__FinancialAccount__c loan = [
                    SELECT Id, Name, FinServ__FinancialAccountType__c,
                           FinServ__PrincipalBalance__c, Current_EMI__c,
                           FinServ__LoanTermMonths__c, FinServ__InterestRate__c,
                           Is_Restructured__c, Last_Restructure_Date__c
                    FROM FinServ__FinancialAccount__c
                    WHERE Id = :req.loanAccountId
                    LIMIT 1
                ];

                // Check 90-day restructuring cooldown (check request records — source of truth)
                List<Loan_Restructuring_Request__c> recentRequests = [
                    SELECT Id, Name, CreatedDate, Selected_Option__c, New_EMI__c,
                           New_Tenure_Months__c, Original_EMI__c, Status__c
                    FROM Loan_Restructuring_Request__c
                    WHERE Loan_Financial_Account__c = :loan.Id
                      AND Status__c = 'Submitted'
                      AND CreatedDate >= :DateTime.newInstance(Date.today().addDays(-90), Time.newInstance(0,0,0,0))
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!recentRequests.isEmpty()) {
                    Loan_Restructuring_Request__c lastReq = recentRequests[0];
                    Date lastSubmitDate = lastReq.CreatedDate.date();
                    Date eligibleDate = lastSubmitDate.addDays(90);

                    String loanInfo = '📋 Your Loan Details:\n'
                        + '   Loan: ' + loan.FinServ__FinancialAccountType__c + ' (' + loan.Name + ')\n'
                        + '   Outstanding: ₹' + formatCurrency(loan.FinServ__PrincipalBalance__c) + '\n'
                        + '   Current EMI: ₹' + formatCurrency(loan.Current_EMI__c) + '/month\n'
                        + '   Tenure: ' + Integer.valueOf(loan.FinServ__LoanTermMonths__c) + ' months\n'
                        + '   Interest Rate: ' + loan.FinServ__InterestRate__c + '%\n\n';

                    String reqInfo = '📄 Last Restructuring Request:\n'
                        + '   Request #: ' + lastReq.Name + '\n'
                        + '   Option: ' + getOptionLabel(lastReq.Selected_Option__c) + '\n'
                        + '   New EMI: ₹' + formatCurrency(lastReq.New_EMI__c) + '/month\n'
                        + '   Submitted: ' + lastSubmitDate.format() + '\n'
                        + '   Status: ' + lastReq.Status__c + '\n\n';

                    String cooldownMsg = '⚠️ You have already restructured this loan within the last 90 days. '
                        + 'You can submit a new restructuring request after ' + eligibleDate.format() + '.';

                    r.success = false;
                    r.message = loanInfo + reqInfo + cooldownMsg;
                    results.add(r);
                    continue;
                }

                Decimal principal = loan.FinServ__PrincipalBalance__c;
                Decimal annualRate = loan.FinServ__InterestRate__c;
                Integer currentTenure = Integer.valueOf(loan.FinServ__LoanTermMonths__c);
                Decimal currentEMI = loan.Current_EMI__c;

                // Option A: Extend by 12 months
                Integer tenureA = currentTenure + 12;
                Decimal emiA = calculateEMI(principal, annualRate, tenureA);
                Decimal totalInterestA = (emiA * tenureA) - principal;
                Decimal currentTotalInterest = (currentEMI * currentTenure) - principal;
                Decimal additionalInterestA = totalInterestA - currentTotalInterest;

                // Option B: Extend by 24 months
                Integer tenureB = currentTenure + 24;
                Decimal emiB = calculateEMI(principal, annualRate, tenureB);
                Decimal totalInterestB = (emiB * tenureB) - principal;
                Decimal additionalInterestB = totalInterestB - currentTotalInterest;

                // Option C: 3-month moratorium (interest-only for 3 months, then resume normal EMI for remaining tenure)
                Decimal monthlyRate = annualRate / 12 / 100;
                Decimal interestOnlyEMI = principal * monthlyRate;
                // After moratorium, principal remains same, tenure unchanged
                Decimal emiC = currentEMI;
                Decimal additionalInterestC = (interestOnlyEMI * 3) - (currentEMI * 3) + (currentEMI * 3);
                // Simplify: additional cost = 3 months of interest-only minus 3 months of normal EMI principal portion
                additionalInterestC = interestOnlyEMI * 3;

                // Format output
                String options = '📊 Loan Restructuring Options for ' + loan.FinServ__FinancialAccountType__c + ' (' + loan.Name + '):\n';
                options += '   Current EMI: ₹' + formatCurrency(currentEMI) + '/month | Tenure: ' + currentTenure + ' months\n\n';

                options += '✅ Option A — Extend by 1 Year (+12 months)\n';
                options += '   New EMI: ₹' + formatCurrency(emiA) + '/month\n';
                options += '   New Tenure: ' + tenureA + ' months\n';
                options += '   Monthly Savings: ₹' + formatCurrency(currentEMI - emiA) + '\n';
                options += '   Additional Interest: ₹' + formatCurrency(additionalInterestA.abs()) + '\n\n';

                options += '✅ Option B — Extend by 2 Years (+24 months)\n';
                options += '   New EMI: ₹' + formatCurrency(emiB) + '/month\n';
                options += '   New Tenure: ' + tenureB + ' months\n';
                options += '   Monthly Savings: ₹' + formatCurrency(currentEMI - emiB) + '\n';
                options += '   Additional Interest: ₹' + formatCurrency(additionalInterestB.abs()) + '\n\n';

                options += '✅ Option C — 3-Month Moratorium\n';
                options += '   Pay only ₹' + formatCurrency(interestOnlyEMI) + '/month for 3 months (interest only)\n';
                options += '   Then resume ₹' + formatCurrency(emiC) + '/month for remaining ' + currentTenure + ' months\n';
                options += '   Total moratorium cost: ₹' + formatCurrency(additionalInterestC) + '\n\n';

                options += 'Please reply with A, B, or C to select your preferred option.';

                r.success = true;
                r.options = options;
                r.optionCount = 3;
                r.message = 'Restructuring options calculated successfully.';
                r.currentEMI = currentEMI;
                r.emiOptionA = emiA;
                r.emiOptionB = emiB;

            } catch (QueryException qe) {
                ZentraErrorLogger.log('ZentraLoanSimulateService', 'simulateRestructuring', qe);
                r.success = false;
                r.message = 'Loan account not found. Please check the loan details.';
            } catch (Exception e) {
                ZentraErrorLogger.log('ZentraLoanSimulateService', 'simulateRestructuring', e);
                r.success = false;
                r.message = 'Error simulating restructuring: ' + e.getMessage();
            }
            results.add(r);
        }
        return results;
    }

    /**
     * EMI = P × r × (1+r)^n / ((1+r)^n - 1)
     */
    public static Decimal calculateEMI(Decimal principal, Decimal annualRate, Integer tenureMonths) {
        if (principal == null || principal <= 0 || annualRate == null || annualRate <= 0 || tenureMonths <= 0) {
            return 0;
        }
        Decimal monthlyRate = annualRate / 12 / 100;
        Double r = monthlyRate.doubleValue();
        Double n = tenureMonths;
        Double factor = Math.pow(1 + r, n);
        Double emi = principal.doubleValue() * r * factor / (factor - 1);
        return Decimal.valueOf(emi).setScale(2, RoundingMode.HALF_UP);
    }

    private static String getOptionLabel(String option) {
        if (option == 'A') return 'A — Extend tenure by 1 year';
        if (option == 'B') return 'B — Extend tenure by 2 years';
        if (option == 'C') return 'C — 3-month moratorium';
        return option;
    }

    private static String formatCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        return String.valueOf(amount.setScale(2));
    }

    public class SimulateRequest {
        @InvocableVariable(label='Loan Account Id' description='FinServ__FinancialAccount__c loan record Id' required=true)
        public Id loanAccountId;
    }

    public class SimulateResult {
        @InvocableVariable(label='Success' description='Whether simulation was successful')
        public Boolean success;

        @InvocableVariable(label='Message' description='Status message')
        public String message;

        @InvocableVariable(label='Options' description='Formatted 3-option comparison string')
        public String options;

        @InvocableVariable(label='Option Count' description='Number of options (always 3)')
        public Integer optionCount;

        @InvocableVariable(label='Current EMI' description='Current monthly EMI')
        public Decimal currentEMI;

        @InvocableVariable(label='EMI Option A' description='New EMI for option A')
        public Decimal emiOptionA;

        @InvocableVariable(label='EMI Option B' description='New EMI for option B')
        public Decimal emiOptionB;
    }
}