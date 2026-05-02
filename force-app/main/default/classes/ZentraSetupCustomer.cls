/**
 * ZentraSetupCustomer
 * @description Creates a fully loaded TruZentra customer with Account, Contact,
 *              Financial Accounts (Savings, Credit Card, Loan), Transactions,
 *              Recurring Payments, SIPs (Mutual Funds), and FinServ__Card__c records.
 *              Run from Anonymous Apex window.
 * @usage       ZentraSetupCustomer.run('Aarav', 'Sharma', 'aarav@test.com', '+919876543210');
 *              ZentraSetupCustomer.run('Aarav', 'Sharma', 'aarav@test.com', '+919876543210', 15, 8);
 * @developer   BlueForce Team
 * @date        2026-04-16
 */
public without sharing class ZentraSetupCustomer {

    /**
     * @description Called from zentraApproveAccount LWC on the New Account Opening Case record.
     *              Reads name/email/phone from the Case, creates the customer, and updates Case to Approved.
     * @param caseId        The Case record Id
     * @param includeTestData  If true, generates Financial Accounts, Transactions, Cards, and Recurring Payments
     * @return              Summary message for the LWC toast
     */
    @AuraEnabled
    public static String approveAndCreateAccount(Id caseId, Boolean includeTestData) {
        Case c = [SELECT Id, SuppliedName, SuppliedEmail, SuppliedPhone, Status,
                         RecordType.DeveloperName
                  FROM Case WHERE Id = :caseId LIMIT 1];

        if (c.RecordType.DeveloperName != 'New_Account_Opening') {
            throw new AuraHandledException('This action is only available for New Account Opening cases.');
        }
        if (c.Status == 'Approved' || c.Status == 'Closed') {
            throw new AuraHandledException('This case has already been processed (Status: ' + c.Status + ').');
        }

        String fullName = String.isNotBlank(c.SuppliedName) ? c.SuppliedName : 'New Customer';
        String[] nameParts = fullName.split(' ', 2);
        String firstName = nameParts[0];
        String lastName = nameParts.size() > 1 ? nameParts[1] : firstName;
        String email = String.isNotBlank(c.SuppliedEmail) ? c.SuppliedEmail : firstName.toLowerCase() + '@zentrabank.com';
        String phone = String.isNotBlank(c.SuppliedPhone) ? c.SuppliedPhone : '+910000000000';

        if (includeTestData == true) {
            run(firstName, lastName, email, phone);
        } else {
            // Create Person Account with core fields — Contact is auto-created
            Account acct = new Account(
                FirstName = firstName,
                LastName  = lastName,
                PersonEmail = email,
                Phone     = phone,
                Zentra_MPIN_Val__c = '000000'
            );
            insert acct;
        }

        // Update Case status to Approved
        c.Status = 'Approved';
        update c;

        return 'Account created for ' + fullName + (includeTestData == true ? ' with test data (Financial Accounts, Transactions, Cards, Recurring Payments, SIPs).' : ' (Account & Contact only).');
    }

    // Default overload — 13 transactions, 6 recurring payments
    public static void run(String firstName, String lastName, String email, String phone) {
        run(firstName, lastName, email, phone, 13, 6);
    }

    public static void run(String firstName, String lastName, String email, String phone,
                           Integer numTransactions, Integer numRecurringPayments) {
        if (numTransactions == null || numTransactions < 0) numTransactions = 13;
        if (numRecurringPayments == null || numRecurringPayments < 0) numRecurringPayments = 6;

        String fullName = firstName + ' ' + lastName;
        Integer rand4   = Math.mod(Math.abs(Crypto.getRandomInteger()), 9000) + 1000;

        // ---------- 1. Person Account (Contact auto-created) ----------
        Account acct = new Account(
            FirstName          = firstName,
            LastName           = lastName,
            PersonEmail        = email,
            Phone              = phone,
            Zentra_MPIN_Val__c = '000000'
        );
        insert acct;

        // ---------- 3. Financial Accounts ----------
        Decimal savingsBalance = Math.round(Math.random() * 400000 + 50000);
        Decimal ccBalance      = Math.round(Math.random() * 80000  + 5000);

        // Loan config
        String[] loanTypes = new String[]{'Loan Account', 'Auto Loan', 'Mortgage'};
        String loanType    = loanTypes[Math.mod(Math.abs(Crypto.getRandomInteger()), 3)];

        Map<String, Decimal> principalMap = new Map<String, Decimal>{
            'Loan Account' => 500000, 'Auto Loan' => 850000, 'Mortgage' => 3500000
        };
        Map<String, Decimal> emiMap = new Map<String, Decimal>{
            'Loan Account' => 12800, 'Auto Loan' => 18200, 'Mortgage' => 29500
        };
        Map<String, Integer> tenureMap = new Map<String, Integer>{
            'Loan Account' => 48, 'Auto Loan' => 60, 'Mortgage' => 180
        };
        Map<String, Decimal> rateMap = new Map<String, Decimal>{
            'Loan Account' => 12.0, 'Auto Loan' => 9.75, 'Mortgage' => 8.5
        };

        Decimal principal = principalMap.get(loanType);
        Integer tenure    = tenureMap.get(loanType);

        String[] branches = new String[]{'Connaught Place, New Delhi', 'Dwarka Sector 12, New Delhi', 'Rajouri Garden, New Delhi', 'Nehru Place, New Delhi', 'Saket, New Delhi', 'Karol Bagh, New Delhi', 'Lajpat Nagar, New Delhi', 'Janakpuri, New Delhi'};
        String branch = branches[Math.mod(Math.abs(Crypto.getRandomInteger()), branches.size())];

        FinServ__FinancialAccount__c savings = new FinServ__FinancialAccount__c(
            Name                             = 'Savings - ' + firstName,
            FinServ__PrimaryOwner__c         = acct.Id,
            FinServ__FinancialAccountType__c = 'Savings Account',
            FinServ__Balance__c              = savingsBalance,
            FinServ__Status__c               = 'Active',
            Account_Number_Masked__c         = 'XXXX-XXXX-' + String.valueOf(rand4),
            FinServ__OpenDate__c             = Date.today().addMonths(-36),
            FinServ__FinancialAccountNumber__c = 'SAV' + String.valueOf(rand4),
            FinServ__BranchName__c             = branch
        );

        Decimal ccLimit = Math.round(Math.random() * 200000 + 100000);
        Decimal ccAvailable = ccLimit - ccBalance;

        FinServ__FinancialAccount__c creditCard = new FinServ__FinancialAccount__c(
            Name                             = 'Credit Card - ' + firstName,
            FinServ__PrimaryOwner__c         = acct.Id,
            FinServ__FinancialAccountType__c = 'Credit Card',
            FinServ__Balance__c              = ccBalance,
            FinServ__Status__c               = 'Active',
            Account_Number_Masked__c         = 'XXXX-XXXX-' + String.valueOf(rand4 + 1),
            FinServ__TotalCreditLimit__c     = ccLimit,
            FinServ__AvailableCredit__c      = ccAvailable,
            FinServ__OpenDate__c             = Date.today().addMonths(-18),
            FinServ__FinancialAccountNumber__c = 'CC' + String.valueOf(rand4 + 1),
            FinServ__BranchName__c             = branch
        );

        FinServ__FinancialAccount__c loanFA = new FinServ__FinancialAccount__c(
            Name                             = loanType + ' - ' + firstName,
            FinServ__PrimaryOwner__c         = acct.Id,
            FinServ__FinancialAccountType__c = loanType,
            FinServ__Balance__c              = principal,
            FinServ__Status__c               = 'Active',
            Account_Number_Masked__c         = 'XXXX-XXXX-' + String.valueOf(rand4 + 2),
            FinServ__FinancialAccountNumber__c = 'LN' + String.valueOf(rand4 + 2),
            FinServ__PrincipalBalance__c     = principal,
            FinServ__LoanAmount__c           = principal,
            FinServ__InterestRate__c         = rateMap.get(loanType),
            FinServ__LoanTermMonths__c       = tenure,
            FinServ__OpenDate__c             = Date.today().addMonths(-24),
            FinServ__LoanEndDate__c          = Date.today().addMonths(tenure - 24),
            Current_EMI__c                   = emiMap.get(loanType),
            Is_Restructured__c               = false,
            FinServ__BranchName__c             = branch
        );

        insert new List<FinServ__FinancialAccount__c>{ savings, creditCard, loanFA };

        // ---------- 4. Credit Card (FinServ__Card__c) ----------
        String[] networks = new String[]{'Visa', 'Mastercard', 'RuPay'};
        String cardNetwork = networks[Math.mod(Math.abs(Crypto.getRandomInteger()), 3)];

        FinServ__Card__c card = new FinServ__Card__c(
            Name                            = cardNetwork + ' ' + firstName + ' Card',
            FinServ__FinancialAccount__c     = creditCard.Id,
            FinServ__AccountHolder__c        = acct.Id,
            FinServ__Active__c               = true,
            FinServ__ValidUntil__c           = Date.today().addYears(3)
        );
        insert card;

        // ---------- 5. Transactions (configurable count) ----------
        List<FinServ__FinancialAccountTransaction__c> txns = new List<FinServ__FinancialAccountTransaction__c>();

        String[] allMerchants  = new String[]{'Swiggy', 'Amazon India', 'BigBasket', 'IRCTC', 'Reliance Fresh', 'Uber India', 'Flipkart', 'Zomato', 'PhonePe', 'Google Pay', 'Paytm Mall', 'BookMyShow', 'DMart', 'Jio Mart', 'Lenskart', 'MakeMyTrip', 'Myntra', 'Netflix India', 'Croma Electronics', 'Taj Hotels', 'Spotify India', 'Zepto', 'Blinkit', 'Nykaa', 'Urban Company'};
        String[] allCategories = new String[]{'Food',   'Shopping',     'Shopping',  'Travel','Shopping',       'Travel',     'Shopping', 'Food',   'Transfer','Transfer',   'Shopping',   'Entertainment','Shopping','Shopping','Shopping', 'Travel',     'Shopping','Entertainment', 'Shopping',           'Travel',    'Entertainment', 'Shopping','Shopping','Shopping','Services'};

        // Split: ~60% savings, ~40% credit card
        Integer savTxnCount = (Integer) Math.ceil(numTransactions * 0.6);
        Integer ccTxnCount  = numTransactions - savTxnCount;

        for (Integer i = 0; i < savTxnCount && i < allMerchants.size(); i++) {
            Decimal amt = Math.round(Math.random() * 4000 + 100);
            txns.add(new FinServ__FinancialAccountTransaction__c(
                FinServ__FinancialAccount__c = savings.Id,
                FinServ__TransactionDate__c  = Date.today().addDays(-i * 2),
                FinServ__Amount__c           = amt,
                FinServ__Description__c      = 'Payment to ' + allMerchants[i],
                Merchant_Name__c             = allMerchants[i],
                Category__c                  = allCategories[i],
                FinServ__TransactionType__c  = 'Debit'
            ));
        }

        for (Integer i = 0; i < ccTxnCount; i++) {
            Integer mIdx = Math.mod(savTxnCount + i, allMerchants.size());
            Decimal amt = Math.round(Math.random() * 15000 + 1000);
            txns.add(new FinServ__FinancialAccountTransaction__c(
                FinServ__FinancialAccount__c = creditCard.Id,
                FinServ__TransactionDate__c  = Date.today().addDays(-i * 3 - 1),
                FinServ__Amount__c           = amt,
                FinServ__Description__c      = 'Purchase at ' + allMerchants[mIdx],
                Merchant_Name__c             = allMerchants[mIdx],
                Category__c                  = allCategories[mIdx],
                FinServ__TransactionType__c  = 'Debit'
            ));
        }

        if (!txns.isEmpty()) { insert txns; }

        // ---------- 6. Recurring Payments (configurable count) ----------
        List<Zentra_Recurring_Payment__c> rpList = createRecurringPayments(
            acct.Id, savings.Id, creditCard.Id, numRecurringPayments
        );
        if (!rpList.isEmpty()) { insert rpList; }

        // ---------- 7. SIPs (Mutual Fund) ----------
        List<FinServ__FinancialHolding__c> sipList = createSIPs(acct.Id, savings.Id);
        if (!sipList.isEmpty()) { insert sipList; }

        // ---------- Summary ----------
        System.debug('═══════════════════════════════════════════════');
        System.debug('  ✅ Customer Setup Complete');
        System.debug('═══════════════════════════════════════════════');
        System.debug('  Name:         ' + fullName);
        System.debug('  Email:        ' + email);
        System.debug('  Phone:        ' + phone);
        System.debug('  Account Id:   ' + acct.Id);
        System.debug('───────────────────────────────────────────────');
        System.debug('  Savings:      ₹' + savingsBalance);
        System.debug('  Credit Card:  ₹' + ccBalance + ' (' + cardNetwork + ')');
        System.debug('  Loan (' + loanType + '): ₹' + principal);
        System.debug('  Card:         ' + card.Id);
        System.debug('  Transactions: ' + txns.size());
        System.debug('  Recurring:    ' + rpList.size());
        System.debug('  SIPs:         ' + sipList.size());
        System.debug('═══════════════════════════════════════════════');
        for (Zentra_Recurring_Payment__c rp : rpList) {
            System.debug('  RP: ' + rp.Payee_Name__c + ' | ₹' + rp.Amount__c + ' | ' + rp.Frequency__c + ' | ' + rp.Status__c);
        }
        for (FinServ__FinancialHolding__c sip : sipList) {
            System.debug('  SIP: ' + sip.Fund_Name__c + ' | ₹' + sip.SIP_Amount__c + ' | ' + sip.Frequency__c + ' | ' + sip.Status__c);
        }
        System.debug('═══════════════════════════════════════════════');
    }

    // ─── Recurring Payment Generator ───
    private static List<Zentra_Recurring_Payment__c> createRecurringPayments(
            Id accountId, Id savingsId, Id creditCardId, Integer count) {

        // Pool of realistic payees with their config
        List<Map<String, Object>> payeePool = new List<Map<String, Object>>{
            new Map<String, Object>{ 'payee' => 'Delhi Electricity Board (BSES)', 'acct' => 'BSES-XXXX-4821', 'amt' => 3200, 'freq' => 'Monthly', 'purpose' => 'Utility Bill', 'remark' => 'Auto-pay for home electricity bill', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'HDFC Mutual Fund - Flexi Cap SIP', 'acct' => 'SIP-MF-77291', 'amt' => 10000, 'freq' => 'Monthly', 'purpose' => 'SIP / Mutual Fund', 'remark' => 'Long-term wealth creation SIP', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Rajesh Mehra (Landlord)', 'acct' => 'ICICI-XXXX-9034', 'amt' => 22000, 'freq' => 'Monthly', 'purpose' => 'Rent', 'remark' => 'Monthly rent for Dwarka Sector 12 flat', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'LIC of India - Jeevan Anand', 'acct' => 'LIC-POL-30219845', 'amt' => 8500, 'freq' => 'Quarterly', 'purpose' => 'Insurance Premium', 'remark' => 'Life insurance premium', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Netflix India', 'acct' => 'NF-SUB-IN-88421', 'amt' => 649, 'freq' => 'Monthly', 'purpose' => 'Subscription', 'remark' => 'Netflix Premium subscription', 'src' => 'cc' },
            new Map<String, Object>{ 'payee' => 'Zentra Bank - Loan EMI', 'acct' => 'LOAN-XXXX-5523', 'amt' => 12800, 'freq' => 'Monthly', 'purpose' => 'Loan EMI', 'remark' => 'Auto-debit for loan EMI', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Star Health Insurance', 'acct' => 'STAR-POL-12098', 'amt' => 4200, 'freq' => 'Yearly', 'purpose' => 'Insurance Premium', 'remark' => 'Cancelled — switched to HDFC Ergo', 'src' => 'savings', 'status' => 'Cancelled' },
            new Map<String, Object>{ 'payee' => 'Axis Bluechip Fund SIP', 'acct' => 'SIP-AX-44210', 'amt' => 5000, 'freq' => 'Monthly', 'purpose' => 'SIP / Mutual Fund', 'remark' => 'Paused temporarily due to liquidity needs', 'src' => 'savings', 'status' => 'Paused' },
            new Map<String, Object>{ 'payee' => 'Spotify India', 'acct' => 'SP-SUB-IN-33109', 'amt' => 179, 'freq' => 'Monthly', 'purpose' => 'Subscription', 'remark' => 'Spotify Premium family plan', 'src' => 'cc' },
            new Map<String, Object>{ 'payee' => 'Tata AIA Life Insurance', 'acct' => 'TATA-POL-90122', 'amt' => 15000, 'freq' => 'Half-Yearly', 'purpose' => 'Insurance Premium', 'remark' => 'Term life insurance', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Delhi Jal Board', 'acct' => 'DJB-XXXX-1190', 'amt' => 850, 'freq' => 'Quarterly', 'purpose' => 'Utility Bill', 'remark' => 'Water bill auto-pay', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Amazon Prime', 'acct' => 'AMZ-PRM-IN-55672', 'amt' => 1499, 'freq' => 'Yearly', 'purpose' => 'Subscription', 'remark' => 'Amazon Prime annual membership', 'src' => 'cc' },
            new Map<String, Object>{ 'payee' => 'ICICI Prudential SIP', 'acct' => 'SIP-IC-88301', 'amt' => 7500, 'freq' => 'Monthly', 'purpose' => 'SIP / Mutual Fund', 'remark' => 'Tax-saving ELSS SIP', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Society Maintenance', 'acct' => 'SOC-DWK-S12-001', 'amt' => 4500, 'freq' => 'Monthly', 'purpose' => 'Maintenance', 'remark' => 'Apartment maintenance charges', 'src' => 'savings' },
            new Map<String, Object>{ 'payee' => 'Airtel Broadband', 'acct' => 'AIRT-BB-77124', 'amt' => 999, 'freq' => 'Monthly', 'purpose' => 'Utility Bill', 'remark' => 'Broadband + DTH combo plan', 'src' => 'savings' }
        };

        List<Zentra_Recurring_Payment__c> payments = new List<Zentra_Recurring_Payment__c>();
        Integer poolSize = payeePool.size();

        for (Integer i = 0; i < count && i < poolSize; i++) {
            Map<String, Object> p = payeePool[i];
            String status = p.containsKey('status') ? (String) p.get('status') : 'Active';
            Id sourceId = ((String) p.get('src') == 'cc') ? creditCardId : savingsId;
            Integer startMonthsAgo = Math.mod(Math.abs(Crypto.getRandomInteger()), 18) + 3;

            Zentra_Recurring_Payment__c rp = new Zentra_Recurring_Payment__c(
                Customer__c             = accountId,
                Source_Account__c       = sourceId,
                Payee_Name__c           = (String) p.get('payee'),
                Payee_Account_Number__c = (String) p.get('acct'),
                Amount__c               = (Decimal) p.get('amt'),
                Frequency__c            = (String) p.get('freq'),
                Start_Date__c           = Date.today().addMonths(-startMonthsAgo),
                Status__c               = status,
                Payment_Purpose__c      = (String) p.get('purpose'),
                Remarks__c              = (String) p.get('remark')
            );

            if (status == 'Active') {
                rp.Next_Payment_Date__c = Date.today().addDays(Math.mod(Math.abs(Crypto.getRandomInteger()), 25) + 1);
                rp.Last_Payment_Date__c = Date.today().addDays(-(Math.mod(Math.abs(Crypto.getRandomInteger()), 25) + 5));
                // Some have end dates, some are indefinite
                if (Math.mod(i, 3) != 0) {
                    rp.End_Date__c = Date.today().addMonths(Math.mod(Math.abs(Crypto.getRandomInteger()), 36) + 6);
                }
            } else if (status == 'Cancelled') {
                rp.End_Date__c = Date.today().addMonths(-Math.mod(Math.abs(Crypto.getRandomInteger()), 6) - 1);
                rp.Last_Payment_Date__c = Date.today().addMonths(-Math.mod(Math.abs(Crypto.getRandomInteger()), 12) - 2);
            } else if (status == 'Paused') {
                rp.End_Date__c = Date.today().addMonths(Math.mod(Math.abs(Crypto.getRandomInteger()), 36) + 12);
                rp.Last_Payment_Date__c = Date.today().addMonths(-Math.mod(Math.abs(Crypto.getRandomInteger()), 3) - 1);
            }

            payments.add(rp);
        }

        return payments;
    }

    // ─── SIP (Mutual Fund) Generator ───
    // Creates parent objects (Securities, Investment Account) then builds SIP records.
    private static List<FinServ__FinancialHolding__c> createSIPs(Id accountId, Id savingsId) {

        // ── 1. Upsert FinServ__Securities__c (Mutual Fund Schemes) ──
        List<Map<String, Object>> fundData = new List<Map<String, Object>>{
            new Map<String, Object>{ 'name' => 'HDFC Flexi Cap Fund - Direct Growth',            'secId' => 'INF179K01BE2', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 1842.50 },
            new Map<String, Object>{ 'name' => 'ICICI Prudential Bluechip Fund - Direct Growth',  'secId' => 'INF109K01AV0', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 985.30  },
            new Map<String, Object>{ 'name' => 'SBI Small Cap Fund - Direct Growth',              'secId' => 'INF200K01RQ1', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 168.75  },
            new Map<String, Object>{ 'name' => 'Axis ELSS Tax Saver Fund - Direct Growth',        'secId' => 'INF846K01EW2', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 425.10  },
            new Map<String, Object>{ 'name' => 'Mirae Asset Large Cap Fund - Direct Growth',       'secId' => 'INF769K01AX8', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 1125.60 },
            new Map<String, Object>{ 'name' => 'Kotak Emerging Equity Fund - Direct Growth',       'secId' => 'INF174K01278', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 112.40  },
            new Map<String, Object>{ 'name' => 'Nippon India Growth Fund - Direct Growth',         'secId' => 'INF204K01GI0', 'cat' => 'Mutual Funds', 'class' => 'Equity', 'price' => 3450.80 }
        };

        List<FinServ__Securities__c> securities = new List<FinServ__Securities__c>();
        for (Map<String, Object> fd : fundData) {
            securities.add(new FinServ__Securities__c(
                FinServ__SecuritiesName__c = (String) fd.get('name'),
                FinServ__SecurityId__c     = (String) fd.get('secId'),
                FinServ__AssetCategory__c  = (String) fd.get('cat'),
                FinServ__AssetClass__c     = (String) fd.get('class'),
                FinServ__Price__c          = (Decimal) fd.get('price'),
                FinServ__Exchange__c       = 'NSE',
                FinServ__LastUpdated__c    = Date.today()
            ));
        }
        upsert securities FinServ__SecuritiesName__c;

        Map<String, Id> securityMap = new Map<String, Id>();
        for (FinServ__Securities__c s : securities) {
            securityMap.put(s.FinServ__SecuritiesName__c, s.Id);
        }

        // ── 2. Create Investment FinancialAccount ──
        FinServ__FinancialAccount__c investmentAcct = new FinServ__FinancialAccount__c(
            Name                              = 'MF Portfolio',
            FinServ__PrimaryOwner__c          = accountId,
            FinServ__FinancialAccountType__c   = 'Investment Account',
            FinServ__Status__c                 = 'Open',
            FinServ__Balance__c                = 597400
        );
        insert investmentAcct;

        // ── 3. Build SIP records ──
        List<Map<String, Object>> sipPool = new List<Map<String, Object>>{
            new Map<String, Object>{ 'fund' => 'HDFC Flexi Cap Fund - Direct Growth',            'folio' => 'HDF-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 10000, 'freq' => 'Monthly', 'day' => 5,  'units' => 245.32, 'invested' => 120000, 'value' => 152800, 'installments' => 12, 'status' => 'Active' },
            new Map<String, Object>{ 'fund' => 'ICICI Prudential Bluechip Fund - Direct Growth',  'folio' => 'ICI-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 5000,  'freq' => 'Monthly', 'day' => 10, 'units' => 198.75, 'invested' => 90000,  'value' => 118200, 'installments' => 18, 'status' => 'Active' },
            new Map<String, Object>{ 'fund' => 'SBI Small Cap Fund - Direct Growth',              'folio' => 'SBI-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 3000,  'freq' => 'Monthly', 'day' => 15, 'units' => 312.50, 'invested' => 72000,  'value' => 95600,  'installments' => 24, 'status' => 'Active' },
            new Map<String, Object>{ 'fund' => 'Axis ELSS Tax Saver Fund - Direct Growth',        'folio' => 'AXS-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 12500, 'freq' => 'Monthly', 'day' => 1,  'units' => 420.10, 'invested' => 150000, 'value' => 178500, 'installments' => 12, 'status' => 'Active' },
            new Map<String, Object>{ 'fund' => 'Mirae Asset Large Cap Fund - Direct Growth',       'folio' => 'MIR-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 7500,  'freq' => 'Monthly', 'day' => 20, 'units' => 156.80, 'invested' => 45000,  'value' => 52300,  'installments' => 6,  'status' => 'Active' },
            new Map<String, Object>{ 'fund' => 'Kotak Emerging Equity Fund - Direct Growth',       'folio' => 'KOT-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 2000,  'freq' => 'Monthly', 'day' => 8,  'units' => 88.40,  'invested' => 24000,  'value' => 21500,  'installments' => 12, 'status' => 'Paused',   'remark' => 'Paused temporarily — liquidity needs' },
            new Map<String, Object>{ 'fund' => 'Nippon India Growth Fund - Direct Growth',         'folio' => 'NIP-' + String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 900000) + 100000), 'amt' => 5000,  'freq' => 'Monthly', 'day' => 12, 'units' => 340.20, 'invested' => 60000,  'value' => 54800,  'installments' => 12, 'status' => 'Cancelled', 'remark' => 'Switched to HDFC Flexi Cap' }
        };

        List<FinServ__FinancialHolding__c> sips = new List<FinServ__FinancialHolding__c>();

        for (Map<String, Object> p : sipPool) {
            String fundName = (String) p.get('fund');
            String status   = (String) p.get('status');
            Integer startMonthsAgo = (Integer) p.get('installments') + Math.mod(Math.abs(Crypto.getRandomInteger()), 6);

            FinServ__FinancialHolding__c sip = new FinServ__FinancialHolding__c(
                FinServ__PrimaryOwner__c      = accountId,
                Source_Account__c             = savingsId,
                FinServ__FinancialAccount__c  = investmentAcct.Id,
                FinServ__Securities__c        = securityMap.get(fundName),
                Fund_Name__c                 = fundName,
                Folio_Number__c              = (String) p.get('folio'),
                SIP_Amount__c                = (Decimal) p.get('amt'),
                Frequency__c                 = (String) p.get('freq'),
                SIP_Day__c                   = (Decimal) p.get('day'),
                Start_Date__c                = Date.today().addMonths(-startMonthsAgo),
                Status__c                    = status,
                FinServ__Shares__c           = (Decimal) p.get('units'),
                Total_Invested__c            = (Decimal) p.get('invested'),
                FinServ__MarketValue__c      = (Decimal) p.get('value'),
                Installments_Completed__c    = (Decimal) p.get('installments')
            );

            if (status == 'Active') {
                sip.Next_Installment_Date__c = Date.today().addDays(Math.mod(Math.abs(Crypto.getRandomInteger()), 25) + 1);
            } else if (status == 'Cancelled') {
                sip.End_Date__c = Date.today().addMonths(-Math.mod(Math.abs(Crypto.getRandomInteger()), 3) - 1);
            } else if (status == 'Paused') {
                sip.End_Date__c = Date.today().addMonths(Math.mod(Math.abs(Crypto.getRandomInteger()), 12) + 6);
            }

            if (p.containsKey('remark')) {
                sip.Remarks__c = (String) p.get('remark');
            }

            sips.add(sip);
        }

        return sips;
    }
}