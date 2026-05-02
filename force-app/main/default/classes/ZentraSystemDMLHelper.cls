/**
 * ZentraSystemDMLHelper
 * @description Performs DML operations in system context to bypass
 *              FSC permission-set-license validation rules that block
 *              guest / service users from updating managed objects.
 * @developer   BlueForce Team
 * @date        2026-04-27
 */
public without sharing class ZentraSystemDMLHelper {

    /**
     * Updates a loan FinancialAccount after a restructuring request is submitted.
     * Runs in system context so FSC PSL checks are bypassed.
     */
    public static void updateLoanAfterRestructuring(
        Id loanAccountId,
        String selectedOption,
        Integer newTenure,
        Decimal newEMI
    ) {
        FinServ__FinancialAccount__c loan = new FinServ__FinancialAccount__c(
            Id = loanAccountId,
            Is_Restructured__c = true,
            Last_Restructure_Date__c = Date.today()
        );
        if (selectedOption != 'C') {
            loan.FinServ__LoanTermMonths__c = newTenure;
            loan.Current_EMI__c = newEMI;
        }
        update loan;
    }
}
