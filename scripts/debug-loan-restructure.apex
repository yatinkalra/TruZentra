// ============================================================
// DEBUG: Loan Details → Simulate → Submit Restructuring
// Run: sf apex run --file scripts/debug-loan-restructure.apex --target-org AF
// ============================================================
// CONFIGURE:
String PHONE = 'ENTER_A_VALID_ACCOUNT_PHONE_NUMBER_HERE';  // Customer phone
String SELECTED_OPTION = 'A'; // A = +12mo, B = +24mo, C = 3mo moratorium

// --- Resolve Account ---
List<Account> accts = [SELECT Id, Name FROM Account WHERE Phone LIKE :('%' + PHONE) LIMIT 1];
if (accts.isEmpty()) { System.debug('ERROR: No account for phone ' + PHONE); return; }
Id acctId = accts[0].Id;
System.debug('=== Account: ' + accts[0].Name + ' (' + acctId + ') ===');

// --- 1. Get Loan Details ---
System.debug('\n=== Step 1: Loan Details ===');
ZentraLoanDetailsService.LoanDetailsRequest ldReq = new ZentraLoanDetailsService.LoanDetailsRequest();
ldReq.customerId = acctId;

List<ZentraLoanDetailsService.LoanDetailsResult> ldRes = ZentraLoanDetailsService.getLoanDetails(
    new List<ZentraLoanDetailsService.LoanDetailsRequest>{ ldReq }
);
System.debug('Success:  ' + ldRes[0].success);
System.debug('Summary:\n' + ldRes[0].loanSummary);
if (!ldRes[0].success) { System.debug('STOP: ' + ldRes[0].message); return; }

// --- Find loan account for simulation ---
FinServ__FinancialAccount__c loan = [
    SELECT Id, FinServ__PrincipalBalance__c, Current_EMI__c, FinServ__LoanTermMonths__c,
           FinServ__InterestRate__c, Is_Restructured__c, Last_Restructure_Date__c
    FROM FinServ__FinancialAccount__c
    WHERE FinServ__PrimaryOwner__c = :acctId
      AND FinServ__FinancialAccountType__c IN ('Loan Account','Auto Loan','Mortgage')
    LIMIT 1
];
System.debug('\nLoan Id:     ' + loan.Id);
System.debug('Principal:   ' + loan.FinServ__PrincipalBalance__c);
System.debug('Current EMI: ' + loan.Current_EMI__c);
System.debug('Tenure:      ' + loan.FinServ__LoanTermMonths__c + ' months');
System.debug('Restructured: ' + loan.Is_Restructured__c);
System.debug('Last Restr:  ' + loan.Last_Restructure_Date__c);

// --- 2. Simulate ---
System.debug('\n=== Step 2: Simulate Restructuring ===');
ZentraLoanSimulateService.SimulateRequest simReq = new ZentraLoanSimulateService.SimulateRequest();
simReq.loanAccountId = loan.Id;

List<ZentraLoanSimulateService.SimulateResult> simRes = ZentraLoanSimulateService.simulate(
    new List<ZentraLoanSimulateService.SimulateRequest>{ simReq }
);
System.debug('Success:  ' + simRes[0].success);
System.debug('Options:\n' + simRes[0].options);

// --- 3. Submit ---
System.debug('\n=== Step 3: Submit Option ' + SELECTED_OPTION + ' ===');
ZentraLoanSubmitService.SubmitRequest subReq = new ZentraLoanSubmitService.SubmitRequest();
subReq.customerId = acctId;
subReq.loanAccountId = loan.Id;
subReq.selectedOption = SELECTED_OPTION;

List<ZentraLoanSubmitService.SubmitResult> subRes = ZentraLoanSubmitService.submitRestructuring(
    new List<ZentraLoanSubmitService.SubmitRequest>{ subReq }
);
System.debug('Success:     ' + subRes[0].success);
System.debug('Request#:    ' + subRes[0].requestNumber);
System.debug('Message:     ' + subRes[0].message);

// --- 4. Check Restructuring Status ---
System.debug('\n=== Step 4: Restructuring Status ===');
ZentraRestructuringStatusService.RestructuringStatusRequest rsReq = new ZentraRestructuringStatusService.RestructuringStatusRequest();
rsReq.customerId = acctId;

List<ZentraRestructuringStatusService.RestructuringStatusResult> rsRes = ZentraRestructuringStatusService.getRestructuringStatus(
    new List<ZentraRestructuringStatusService.RestructuringStatusRequest>{ rsReq }
);
System.debug('Success: ' + rsRes[0].success);
System.debug('Summary:\n' + rsRes[0].statusSummary);
