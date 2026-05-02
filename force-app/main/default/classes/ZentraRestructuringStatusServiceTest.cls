@IsTest
private class ZentraRestructuringStatusServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Restructure Status Test');
        insert acct;

        FinServ__FinancialAccount__c loan = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Loan Account',
            FinServ__PrincipalBalance__c = 500000,
            FinServ__InterestRate__c = 10.5,
            FinServ__LoanTermMonths__c = 36,
            Current_EMI__c = 16200,
            FinServ__Status__c = 'Active'
        );
        insert loan;

        Loan_Restructuring_Request__c lr = new Loan_Restructuring_Request__c(
            Customer__c = acct.Id,
            Loan_Financial_Account__c = loan.Id,
            Status__c = 'Submitted',
            Selected_Option__c = 'A',
            Original_EMI__c = 16200,
            New_EMI__c = 14500,
            New_Tenure_Months__c = 48,
            Additional_Interest__c = 25000,
            OTP_Confirmed__c = true
        );
        insert lr;
    }

    @IsTest
    static void testGetStatus_WithRequest() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Restructure Status Test' LIMIT 1];

        ZentraRestructuringStatusService.RestructuringStatusRequest req =
            new ZentraRestructuringStatusService.RestructuringStatusRequest();
        req.customerId = String.valueOf(acct.Id);

        Test.startTest();
        List<ZentraRestructuringStatusService.RestructuringStatusResult> results =
            ZentraRestructuringStatusService.getRestructuringStatus(
                new List<ZentraRestructuringStatusService.RestructuringStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(1, results[0].requestCount);
        System.assert(results[0].statusSummary.contains('Restructuring Status'));
    }

    @IsTest
    static void testGetStatus_NoRequests() {
        Account noReqs = new Account(Name = 'No Restructure Acct');
        insert noReqs;

        ZentraRestructuringStatusService.RestructuringStatusRequest req =
            new ZentraRestructuringStatusService.RestructuringStatusRequest();
        req.customerId = String.valueOf(noReqs.Id);

        Test.startTest();
        List<ZentraRestructuringStatusService.RestructuringStatusResult> results =
            ZentraRestructuringStatusService.getRestructuringStatus(
                new List<ZentraRestructuringStatusService.RestructuringStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(0, results[0].requestCount);
    }

    @IsTest
    static void testGetStatus_BlankCustomerId() {
        ZentraRestructuringStatusService.RestructuringStatusRequest req =
            new ZentraRestructuringStatusService.RestructuringStatusRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraRestructuringStatusService.RestructuringStatusResult> results =
            ZentraRestructuringStatusService.getRestructuringStatus(
                new List<ZentraRestructuringStatusService.RestructuringStatusRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }
}
