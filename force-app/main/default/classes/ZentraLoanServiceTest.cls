@IsTest
private class ZentraLoanServiceTest {

    @TestSetup
    static void setupTestData() {
        Account acct = new Account(Name = 'Loan Test Customer');
        insert acct;

        Contact con = new Contact(
            LastName = 'LoanTest', FirstName = 'Test',
            Email = 'loan.test@example.com', AccountId = acct.Id
        );
        insert con;

        FinServ__FinancialAccount__c loan = new FinServ__FinancialAccount__c(
            FinServ__PrimaryOwner__c = acct.Id,
            FinServ__FinancialAccountType__c = 'Loan Account',
            FinServ__PrincipalBalance__c = 500000,
            FinServ__InterestRate__c = 10.5,
            FinServ__LoanTermMonths__c = 36,
            FinServ__LoanAmount__c = 800000,
            FinServ__OpenDate__c = Date.today().addYears(-1),
            FinServ__LoanEndDate__c = Date.today().addYears(2),
            Current_EMI__c = 16200,
            FinServ__Status__c = 'Active'
        );
        insert loan;
    }

    // ─── ZentraLoanDetailsService Tests ──────────────────────

    @IsTest
    static void testGetLoanDetails_Success() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];

        ZentraLoanDetailsService.LoanDetailsRequest req = new ZentraLoanDetailsService.LoanDetailsRequest();
        req.customerId = acct.Id;

        Test.startTest();
        List<ZentraLoanDetailsService.LoanDetailsResult> results =
            ZentraLoanDetailsService.getLoanDetails(
                new List<ZentraLoanDetailsService.LoanDetailsRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(1, results[0].loanCount);
        System.assert(results[0].loanSummary.contains('Loan'));
    }

    @IsTest
    static void testGetLoanDetails_NoLoans() {
        Account noLoan = new Account(Name = 'No Loans Acct');
        insert noLoan;

        ZentraLoanDetailsService.LoanDetailsRequest req = new ZentraLoanDetailsService.LoanDetailsRequest();
        req.customerId = noLoan.Id;

        Test.startTest();
        List<ZentraLoanDetailsService.LoanDetailsResult> results =
            ZentraLoanDetailsService.getLoanDetails(
                new List<ZentraLoanDetailsService.LoanDetailsRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assertEquals(0, results[0].loanCount);
    }

    @IsTest
    static void testGetLoanDetails_WithRestructuring() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        Loan_Restructuring_Request__c lrr = new Loan_Restructuring_Request__c(
            Customer__c = acct.Id,
            Loan_Financial_Account__c = loan.Id,
            Selected_Option__c = 'A',
            Original_EMI__c = 16200,
            New_EMI__c = 14500,
            New_Tenure_Months__c = 48,
            Additional_Interest__c = 25000,
            Status__c = 'Submitted'
        );
        insert lrr;

        ZentraLoanDetailsService.LoanDetailsRequest req = new ZentraLoanDetailsService.LoanDetailsRequest();
        req.customerId = acct.Id;

        Test.startTest();
        List<ZentraLoanDetailsService.LoanDetailsResult> results =
            ZentraLoanDetailsService.getLoanDetails(
                new List<ZentraLoanDetailsService.LoanDetailsRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].loanSummary.contains('Last Restructuring'), 'Should include restructuring details');
        System.assert(results[0].loanSummary.contains('IMPORTANT'), 'Should include cooldown warning');
    }

    @IsTest
    static void testGetLoanDetails_BlankCustomerId() {
        ZentraLoanDetailsService.LoanDetailsRequest req = new ZentraLoanDetailsService.LoanDetailsRequest();
        req.customerId = '';

        Test.startTest();
        List<ZentraLoanDetailsService.LoanDetailsResult> results =
            ZentraLoanDetailsService.getLoanDetails(
                new List<ZentraLoanDetailsService.LoanDetailsRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('required'));
    }

    // ─── ZentraLoanSimulateService Tests ─────────────────────

    @IsTest
    static void testSimulateLoan_Success() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSimulateService.SimulateRequest req = new ZentraLoanSimulateService.SimulateRequest();
        req.loanAccountId = loan.Id;

        Test.startTest();
        List<ZentraLoanSimulateService.SimulateResult> results =
            ZentraLoanSimulateService.simulate(
                new List<ZentraLoanSimulateService.SimulateRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(results[0].options.contains('Option'));
    }

    @IsTest
    static void testSimulateLoan_NoLoanId() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];

        ZentraLoanSimulateService.SimulateRequest req = new ZentraLoanSimulateService.SimulateRequest();

        Test.startTest();
        List<ZentraLoanSimulateService.SimulateResult> results =
            ZentraLoanSimulateService.simulate(
                new List<ZentraLoanSimulateService.SimulateRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testSimulateLoan_RecentRestructure() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        // Create a recent submitted restructuring request to trigger 90-day cooldown
        Loan_Restructuring_Request__c lrr = new Loan_Restructuring_Request__c(
            Customer__c = acct.Id,
            Loan_Financial_Account__c = loan.Id,
            Selected_Option__c = 'A',
            Original_EMI__c = 16200,
            New_EMI__c = 14500,
            New_Tenure_Months__c = 48,
            Additional_Interest__c = 25000,
            Status__c = 'Submitted'
        );
        insert lrr;

        ZentraLoanSimulateService.SimulateRequest req = new ZentraLoanSimulateService.SimulateRequest();
        req.loanAccountId = loan.Id;

        Test.startTest();
        List<ZentraLoanSimulateService.SimulateResult> results =
            ZentraLoanSimulateService.simulate(
                new List<ZentraLoanSimulateService.SimulateRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('90'));
    }

    // ─── ZentraLoanSubmitService Tests ───────────────────────

    @IsTest
    static void testSubmitLoan_OptionA() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSubmitService.SubmitRequest req = new ZentraLoanSubmitService.SubmitRequest();
        req.customerId = acct.Id;
        req.loanAccountId = loan.Id;
        req.selectedOption = 'A';

        Test.startTest();
        List<ZentraLoanSubmitService.SubmitResult> results =
            ZentraLoanSubmitService.submitRestructuring(
                new List<ZentraLoanSubmitService.SubmitRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertNotEquals(null, results[0].requestNumber);
    }

    @IsTest
    static void testSubmitLoan_OptionB() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSubmitService.SubmitRequest req = new ZentraLoanSubmitService.SubmitRequest();
        req.customerId = acct.Id;
        req.loanAccountId = loan.Id;
        req.selectedOption = 'B';

        Test.startTest();
        List<ZentraLoanSubmitService.SubmitResult> results =
            ZentraLoanSubmitService.submitRestructuring(
                new List<ZentraLoanSubmitService.SubmitRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSubmitLoan_OptionC() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSubmitService.SubmitRequest req = new ZentraLoanSubmitService.SubmitRequest();
        req.customerId = acct.Id;
        req.loanAccountId = loan.Id;
        req.selectedOption = 'C';

        Test.startTest();
        List<ZentraLoanSubmitService.SubmitResult> results =
            ZentraLoanSubmitService.submitRestructuring(
                new List<ZentraLoanSubmitService.SubmitRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
    }

    @IsTest
    static void testSubmitLoan_MissingOption() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSubmitService.SubmitRequest req = new ZentraLoanSubmitService.SubmitRequest();
        req.customerId = acct.Id;
        req.loanAccountId = loan.Id;

        Test.startTest();
        List<ZentraLoanSubmitService.SubmitResult> results =
            ZentraLoanSubmitService.submitRestructuring(
                new List<ZentraLoanSubmitService.SubmitRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }

    @IsTest
    static void testSubmitLoan_InvalidOption() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Loan Test Customer' LIMIT 1];
        FinServ__FinancialAccount__c loan = [
            SELECT Id FROM FinServ__FinancialAccount__c
            WHERE FinServ__PrimaryOwner__c = :acct.Id
              AND FinServ__FinancialAccountType__c = 'Loan Account' LIMIT 1
        ];

        ZentraLoanSubmitService.SubmitRequest req = new ZentraLoanSubmitService.SubmitRequest();
        req.customerId = acct.Id;
        req.loanAccountId = loan.Id;
        req.selectedOption = 'Z';

        Test.startTest();
        List<ZentraLoanSubmitService.SubmitResult> results =
            ZentraLoanSubmitService.submitRestructuring(
                new List<ZentraLoanSubmitService.SubmitRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
    }
}
