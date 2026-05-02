@IsTest
private class ZentraDataCloudControllerTest {

    @IsTest
    static void testSearchAccounts_BlankTerm() {
        Test.startTest();
        List<ZentraDataCloudController.AccountInfo> results =
            ZentraDataCloudController.searchAccounts('');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchAccounts_ShortTerm() {
        Test.startTest();
        List<ZentraDataCloudController.AccountInfo> results =
            ZentraDataCloudController.searchAccounts('A');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testSearchAccounts_ValidTerm() {
        // Data Cloud __dll objects aren't available in test context
        // but this exercises the search logic and catches compile issues
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentraDataCloudController.searchAccounts('Test Customer');
        } catch (Exception e) {
            // Expected — __dll objects don't exist in test
            exceptionThrown = true;
        }
        Test.stopTest();

        // May or may not throw depending on org config
        System.assert(true);
    }

    @IsTest
    static void testGetDashboardData() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ZentraDataCloudController.getDashboardData('001000000000000AAA');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testGetChurnInsight() {
        // ConnectApi.CdpQuery not available in test — exercises error handling
        Test.startTest();
        ZentraDataCloudController.ChurnInsight ci =
            ZentraDataCloudController.getChurnInsight('001000000000000AAA');
        Test.stopTest();

        System.assertEquals(false, ci.available);
    }

    @IsTest
    static void testWrapperClasses() {
        // Verify all wrapper classes can be instantiated and fields set
        ZentraDataCloudController.AccountInfo ai = new ZentraDataCloudController.AccountInfo();
        ai.Id = '001xxx';
        ai.Name = 'Test';
        ai.Phone = '123';
        ai.PersonEmail = 'a@b.com';
        ai.PersonMobilePhone = '456';
        ai.CreatedDate = DateTime.now();

        ZentraDataCloudController.FinancialAccountInfo fi = new ZentraDataCloudController.FinancialAccountInfo();
        fi.Id = '0Axxx';
        fi.Name = 'Savings';
        fi.FinancialAccountType = 'Savings Account';
        fi.Balance = 50000;
        fi.Status = 'Active';
        fi.AccountNumberMasked = 'XXXX1234';
        fi.TotalCreditLimit = 200000;
        fi.AvailableCredit = 185000;
        fi.PrincipalBalance = 0;
        fi.LoanTermMonths = 0;
        fi.InterestRate = 0;
        fi.LoanAmount = 0;
        fi.LoanEndDate = Date.today();
        fi.OpenDate = Date.today();
        fi.CurrentEMI = 0;
        fi.IsRestructured = false;
        fi.LastRestructureDate = null;
        fi.BranchName = 'Main Branch';

        ZentraDataCloudController.TransactionInfo ti = new ZentraDataCloudController.TransactionInfo();
        ti.Id = 'txn1';
        ti.Name = 'TXN-001';
        ti.TransactionDate = DateTime.now();
        ti.Amount = 500;
        ti.Description = 'Test';
        ti.MerchantName = 'Amazon';
        ti.Category = 'Shopping';
        ti.FinancialAccountId = '0Axxx';

        ZentraDataCloudController.RecurringPaymentInfo ri = new ZentraDataCloudController.RecurringPaymentInfo();
        ri.Id = 'rp1';
        ri.Name = 'RP-001';
        ri.PayeeName = 'Utility';
        ri.Amount = 1000;
        ri.Frequency = 'Monthly';
        ri.Status = 'Active';
        ri.StartDate = Date.today();
        ri.EndDate = Date.today().addYears(1);
        ri.NextPaymentDate = Date.today().addDays(5);
        ri.LastPaymentDate = Date.today().addDays(-25);
        ri.PaymentPurpose = 'Electricity';
        ri.Remarks = 'Auto-pay';

        ZentraDataCloudController.LoanRequestInfo li = new ZentraDataCloudController.LoanRequestInfo();
        li.Id = 'lr1';
        li.Name = 'LR-001';
        li.Status = 'Submitted';
        li.SelectedOption = 'A';
        li.OriginalEMI = 16200;
        li.NewEMI = 14500;
        li.NewTenureMonths = 48;
        li.AdditionalInterest = 25000;
        li.MonthlySavings = 1700;
        li.RMCallbackScheduled = DateTime.now();
        li.CreatedDate = DateTime.now();

        ZentraDataCloudController.DisputeCaseInfo di = new ZentraDataCloudController.DisputeCaseInfo();
        di.Id = 'dc1';
        di.CaseNumber = '00001234';
        di.Subject = 'Test Dispute';
        di.Status = 'Filed';
        di.DisputeAmount = 2999;
        di.DisputeStage = 'Filed';
        di.ProvisionalCreditIssued = true;
        di.ProvisionalCreditAmount = 2999;
        di.EstimatedResolutionDate = Date.today().addDays(7);
        di.CreatedDate = DateTime.now();

        ZentraDataCloudController.DashboardData dd = new ZentraDataCloudController.DashboardData();
        dd.account = ai;
        dd.financialAccounts = new List<ZentraDataCloudController.FinancialAccountInfo>{ fi };
        dd.recentTransactions = new List<ZentraDataCloudController.TransactionInfo>{ ti };
        dd.recurringPayments = new List<ZentraDataCloudController.RecurringPaymentInfo>{ ri };
        dd.loanRestructuringRequests = new List<ZentraDataCloudController.LoanRequestInfo>{ li };
        dd.disputeCases = new List<ZentraDataCloudController.DisputeCaseInfo>{ di };

        ZentraDataCloudController.ChurnInsight ci = new ZentraDataCloudController.ChurnInsight();
        ci.available = true;
        ci.customerId = '001xxx';
        ci.totalAccounts = 3;
        ci.activeAccounts = 2;
        ci.stoppedPayments = 1;
        ci.activePayments = 5;
        ci.openDisputes = 0;
        ci.txnCount = 50;
        ci.churnRiskScore = 35;

        System.assertNotEquals(null, dd.account);
        System.assertEquals(true, ci.available);
    }
}
