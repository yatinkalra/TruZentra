import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAccounts from '@salesforce/apex/ZentraRMDashboardController.searchAccounts';
import getDashboardData from '@salesforce/apex/ZentraRMDashboardController.getDashboardData';
import freezeFinancialAccount from '@salesforce/apex/ZentraRMDashboardController.freezeFinancialAccount';
import reactivateFinancialAccount from '@salesforce/apex/ZentraRMDashboardController.reactivateFinancialAccount';
import freezeCard from '@salesforce/apex/ZentraRMDashboardController.freezeCard';
import reactivateCard from '@salesforce/apex/ZentraRMDashboardController.reactivateCard';
import fileTransactionDispute from '@salesforce/apex/ZentraRMDashboardController.fileTransactionDispute';
import stopRecurringPayment from '@salesforce/apex/ZentraRMDashboardController.stopRecurringPayment';
import deactivateAllAccountsAndCards from '@salesforce/apex/ZentraRMDashboardController.deactivateAllAccountsAndCards';
import reactivateAllAccountsAndCards from '@salesforce/apex/ZentraRMDashboardController.reactivateAllAccountsAndCards';

const LOAN_TYPES = new Set(['Loan Account', 'Auto Loan', 'Mortgage']);

export default class ZentraRMDashboard extends LightningElement {
    searchTerm = '';
    searchResults = [];
    showSearchResults = false;
    noSearchResults = false;
    isLoading = false;
    dashboardData = null;
    selectedAccountId = null;
    selectedAccountName = '';
    _searchTimeout;

    // Dispute modal state
    showDisputeModal = false;
    disputeTransaction = null;
    selectedDisputeType = '';
    disputeDescription = '';
    isDisputeSubmitting = false;

    // ── Computed: States ──
    get showEmptyState() { return !this.isLoading && !this.dashboardData; }
    get hasData() { return !!this.dashboardData; }

    // ── Computed: Contact ──
    get contactEmail() { return this.dashboardData?.primaryContact?.Email; }
    get contactPhone() { return this.dashboardData?.primaryContact?.Phone || this.dashboardData?.account?.Phone; }
    get accountUrl() { return '/' + this.dashboardData?.account?.Id; }

    // ── Computed: Summary Stats ──
    get totalFinancialAccounts() { return this.dashboardData?.financialAccounts?.length || 0; }
    get activeRecurringPayments() {
        return (this.dashboardData?.recurringPayments || []).filter(r => r.Status__c === 'Active').length;
    }
    get openDisputes() {
        return (this.dashboardData?.disputeCases || []).filter(c => c.Dispute_Stage__c !== 'Resolved' && c.Dispute_Stage__c !== 'Rejected').length;
    }
    get totalLoanRequests() { return this.dashboardData?.loanRestructuringRequests?.length || 0; }
    get totalCards() { return this.dashboardData?.cards?.length || 0; }
    get recentTransactionCount() { return this.dashboardData?.recentTransactions?.length || 0; }
    get totalSIPs() { return this.dashboardData?.sipRecords?.length || 0; }
    get activeSIPs() {
        return (this.dashboardData?.sipRecords || []).filter(s => s.Status__c === 'Active').length;
    }

    // ── Computed: Has data flags ──
    get hasFinancialAccounts() { return this.totalFinancialAccounts > 0; }
    get hasCards() { return this.totalCards > 0; }
    get hasTransactions() { return this.recentTransactionCount > 0; }
    get hasRecurringPayments() { return (this.dashboardData?.recurringPayments?.length || 0) > 0; }
    get hasLoanRequests() { return this.totalLoanRequests > 0; }
    get hasDisputes() { return (this.dashboardData?.disputeCases?.length || 0) > 0; }
    get hasOTPSessions() { return (this.dashboardData?.recentOTPSessions?.length || 0) > 0; }
    get hasEmailLogs() { return (this.dashboardData?.recentEmailLogs?.length || 0) > 0; }
    get hasErrorLogs() { return (this.dashboardData?.recentErrorLogs?.length || 0) > 0; }
    get hasSIPs() { return this.totalSIPs > 0; }

    // ── Computed: Activate/Deactivate All visibility (mutually exclusive) ──
    get allSavingsAndCardsInactive() {
        const fas = (this.dashboardData?.financialAccounts || [])
            .filter(fa => fa.FinServ__FinancialAccountType__c === 'Savings Account' || fa.FinServ__FinancialAccountType__c === 'Credit Card');
        const cards = this.dashboardData?.cards || [];
        if (fas.length === 0 && cards.length === 0) return false;
        const allFAInactive = fas.every(fa => fa.FinServ__Status__c !== 'Active');
        const allCardsInactive = cards.every(c => c.FinServ__Active__c !== true);
        return allFAInactive && allCardsInactive;
    }
    get showActivateAllBtn() { return this.hasData && this.allSavingsAndCardsInactive; }
    get showDeactivateAllBtn() { return this.hasData && !this.allSavingsAndCardsInactive; }

    // ── Computed: Tab Labels ──
    get financialAccountsTabLabel() { return `Accounts (${this.totalFinancialAccounts})`; }
    get transactionsTabLabel() { return `Transactions (${this.recentTransactionCount})`; }
    get recurringTabLabel() { return `Recurring (${this.dashboardData?.recurringPayments?.length || 0})`; }
    get loanTabLabel() { return `Loans (${this.totalLoanRequests})`; }
    get disputeTabLabel() { return `Disputes (${this.dashboardData?.disputeCases?.length || 0})`; }
    get sipTabLabel() { return `SIPs / MF (${this.totalSIPs})`; }

    // ── Computed: Financial Account Cards ──
    get financialAccountCards() {
        return (this.dashboardData?.financialAccounts || []).map(fa => {
            const faType = fa.FinServ__FinancialAccountType__c;
            const isLoan = LOAN_TYPES.has(faType);
            const isCreditCard = faType === 'Credit Card';
            const isSavings = faType === 'Savings Account';
            let typeLabel = fa.FinServ__FinancialAccountType__c || 'Account';
            let cardColor = isSavings ? 'fa-card fa-savings' : isCreditCard ? 'fa-card fa-credit' : 'fa-card fa-loan';
            let balance = isLoan
                ? (fa.FinServ__PrincipalBalance__c || fa.FinServ__LoanAmount__c || 0)
                : (fa.FinServ__Balance__c || 0);
            return {
                ...fa,
                isLoan,
                isCreditCard,
                typeLabel,
                cardClass: cardColor,
                displayBalance: this._formatCurrency(balance),
                statusClass: fa.FinServ__Status__c === 'Active' ? 'status-badge status-active' : 'status-badge status-inactive',
                emiDisplay: this._formatCurrency(fa.Current_EMI__c || 0),
                rateDisplay: (fa.FinServ__InterestRate__c || 0) + '%',
                tenureDisplay: (fa.FinServ__LoanTermMonths__c || 0) + ' mo',
                creditLimitDisplay: this._formatCurrency(fa.FinServ__TotalCreditLimit__c || 0),
                availableCreditDisplay: this._formatCurrency(fa.FinServ__AvailableCredit__c || 0),
                isActive: fa.FinServ__Status__c === 'Active',
                isFrozen: fa.FinServ__Status__c !== 'Active',
                isSavings,
                branchDisplay: fa.FinServ__BranchName__c || '—',
                canFreeze: !isLoan && fa.FinServ__Status__c === 'Active',
                canReactivate: !isLoan && fa.FinServ__Status__c !== 'Active'
            };
        });
    }

    // ── Computed: Card Items ──
    get cardItems() {
        return (this.dashboardData?.cards || []).map(c => ({
            ...c,
            typeLabel: c.Name || 'Card',
            statusLabel: c.FinServ__Active__c ? 'Active' : 'Inactive',
            statusClass: c.FinServ__Active__c ? 'status-badge status-active' : 'status-badge status-inactive',
            expiryDisplay: c.FinServ__ValidUntil__c || '—',
            accountName: c.FinServ__FinancialAccount__r?.Name || '—',
            isCardActive: c.FinServ__Active__c === true,
            isCardFrozen: c.FinServ__Active__c !== true
        }));
    }

    // ── Column Definitions ──
    get transactionColumns() {
        return [
            { label: 'Date', fieldName: 'FinServ__TransactionDate__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' }, sortable: true },
            { label: 'Description', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'FinServ__Description__c' }, target: '_blank' } },
            { label: 'Merchant', fieldName: 'Merchant_Name__c', type: 'text' },
            { label: 'Category', fieldName: 'Category__c', type: 'text' },
            { label: 'Amount', fieldName: 'FinServ__Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' }, cellAttributes: { alignment: 'right' } },
            { label: 'Action', type: 'button', typeAttributes: { label: 'Dispute', name: 'file_dispute', variant: 'destructive', iconName: 'utility:warning' }, fixedWidth: 150 }
        ];
    }

    get recurringPaymentColumns() {
        return [
            { label: 'Payee', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Payee_Name__c' }, target: '_blank' } },
            { label: 'Amount', fieldName: 'Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Frequency', fieldName: 'Frequency__c', type: 'text' },
            { label: 'Status', fieldName: 'Status__c', type: 'text' },
            { label: 'Purpose', fieldName: 'Payment_Purpose__c', type: 'text' },
            { label: 'Next Payment', fieldName: 'Next_Payment_Date__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } },
            { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } },
            { label: 'Action', type: 'button', typeAttributes: { label: 'Stop', name: 'stop_payment', variant: 'destructive', iconName: 'utility:stop', disabled: { fieldName: 'isStopped' } }, fixedWidth: 130 }
        ];
    }

    get loanColumns() {
        return [
            { label: 'Request #', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' } },
            { label: 'Status', fieldName: 'Status__c', type: 'text' },
            { label: 'Option', fieldName: 'Selected_Option__c', type: 'text' },
            { label: 'Original EMI', fieldName: 'Original_EMI__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'New EMI', fieldName: 'New_EMI__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Savings/mo', fieldName: 'Monthly_Savings__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'RM Callback', fieldName: 'RM_Callback_Scheduled__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' } },
            { label: 'Created', fieldName: 'CreatedDate', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } }
        ];
    }

    get disputeColumns() {
        return [
            { label: 'Case #', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'CaseNumber' }, target: '_blank' } },
            { label: 'Status', fieldName: 'Status', type: 'text' },
            { label: 'Stage', fieldName: 'Dispute_Stage__c', type: 'text' },
            { label: 'Amount', fieldName: 'Dispute_Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Prov. Credit', fieldName: 'Provisional_Credit_Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Resolution Date', fieldName: 'Estimated_Resolution_Date__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } },
            { label: 'Created', fieldName: 'CreatedDate', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } }
        ];
    }

    get otpColumns() {
        return [
            { label: 'Session', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, fixedWidth: 140 },
            { label: 'Date', fieldName: 'CreatedDate', type: 'date', typeAttributes: { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' } },
            { label: 'Phone', fieldName: 'Phone_Number__c', type: 'phone' },
            { label: 'Status', fieldName: 'Status__c', type: 'text' },
            { label: 'Attempts', fieldName: 'Attempt_Count__c', type: 'number' },
            { label: 'Channel', fieldName: 'Channel__c', type: 'text' },
            { label: 'Expires', fieldName: 'Expires_At__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' } }
        ];
    }

    get emailLogColumns() {
        return [
            { label: 'Log', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, fixedWidth: 140 },
            { label: 'Date', fieldName: 'CreatedDate', type: 'date', typeAttributes: { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' } },
            { label: 'Type', fieldName: 'Email_Type__c', type: 'text' },
            { label: 'Recipient', fieldName: 'Recipient_Email__c', type: 'email' },
            { label: 'Subject', fieldName: 'Subject__c', type: 'text' },
            { label: 'Status', fieldName: 'Status__c', type: 'text' }
        ];
    }

    get sipColumns() {
        return [
            { label: 'Fund', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Fund_Name__c' }, target: '_blank' } },
            { label: 'Folio', fieldName: 'Folio_Number__c', type: 'text' },
            { label: 'SIP Amount', fieldName: 'SIP_Amount__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Frequency', fieldName: 'Frequency__c', type: 'text' },
            { label: 'Status', fieldName: 'Status__c', type: 'text' },
            { label: 'Invested', fieldName: 'Total_Invested__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Current Value', fieldName: 'FinServ__MarketValue__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } },
            { label: 'Units', fieldName: 'FinServ__Shares__c', type: 'number', typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
            { label: 'Installments', fieldName: 'Installments_Completed__c', type: 'number' },
            { label: 'Next SIP', fieldName: 'Next_Installment_Date__c', type: 'date', typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } }
        ];
    }

    get errorLogColumns() {
        return [
            { label: 'Log', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'Name' }, target: '_blank' }, fixedWidth: 140 },
            { label: 'Date', fieldName: 'CreatedDate', type: 'date', typeAttributes: { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' } },
            { label: 'Class', fieldName: 'Source_Class__c', type: 'text' },
            { label: 'Method', fieldName: 'Method__c', type: 'text' },
            { label: 'Message', fieldName: 'Error_Message__c', type: 'text', wrapText: true },
            { label: 'Severity', fieldName: 'Severity__c', type: 'text' }
        ];
    }

    // ── Search Handlers ──
    handleSearchChange(event) {
        const val = event.target.value;
        this.searchTerm = val;
        clearTimeout(this._searchTimeout);
        if (!val || val.length < 2) {
            this.searchResults = [];
            this.showSearchResults = false;
            this.noSearchResults = false;
            return;
        }
        this._searchTimeout = setTimeout(() => { this._doSearch(val); }, 300);
    }

    async _doSearch(term) {
        try {
            const results = await searchAccounts({ searchTerm: term });
            this.searchResults = results;
            this.showSearchResults = true;
            this.noSearchResults = results.length === 0;
        } catch (error) {
            console.error('Search error:', error);
            this.searchResults = [];
            this.showSearchResults = false;
        }
    }

    handleAccountSelect(event) {
        const accId = event.currentTarget.dataset.id;
        const accName = event.currentTarget.dataset.name;
        this.selectedAccountId = accId;
        this.selectedAccountName = accName;
        this.searchTerm = '';
        this.searchResults = [];
        this.showSearchResults = false;
        this.noSearchResults = false;
        this._loadDashboard(accId);
    }

    handleRefresh() {
        if (this.selectedAccountId) {
            this._loadDashboard(this.selectedAccountId);
            this._showToast('Refreshing', 'Reloading all dashboard data...', 'info');
        }
    }

    handleClearSelection() {
        this.selectedAccountId = null;
        this.selectedAccountName = '';
        this.dashboardData = null;
        this.searchTerm = '';
    }

    async _loadDashboard(accountId) {
        this.isLoading = true;
        this.dashboardData = null;
        try {
            const data = await getDashboardData({ accountId });
            const urlKeys = ['recentTransactions','recurringPayments','loanRestructuringRequests',
                             'disputeCases','recentOTPSessions','recentEmailLogs','recentErrorLogs','sipRecords'];
            for (const key of urlKeys) {
                if (data[key]) {
                    data[key] = data[key].map(r => ({ ...r, recordUrl: '/' + r.Id }));
                }
            }
            if (data.recurringPayments) {
                data.recurringPayments = data.recurringPayments.map(r => ({ ...r, isStopped: r.Status__c !== 'Active' }));
            }
            this.dashboardData = data;
        } catch (error) {
            console.error('Dashboard load error:', error);
            this.dashboardData = null;
        } finally {
            this.isLoading = false;
        }
    }

    // ── Stop Recurring Payment ──
    handleRecurringRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'stop_payment') {
            this._stopPayment(row.Id);
        }
    }

    async _stopPayment(paymentId) {
        try {
            await stopRecurringPayment({ paymentId });
            this._showToast('Payment Stopped', 'Recurring payment has been cancelled.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to stop payment', 'error');
        }
    }

    // ── Global Deactivate All ──
    async handleDeactivateAll() {
        if (!confirm('⚠️ This will make ALL Savings accounts and Cards INACTIVE for this customer. Continue?')) {
            return;
        }
        try {
            await deactivateAllAccountsAndCards({ accountId: this.selectedAccountId });
            this._showToast('All Deactivated', 'All savings accounts and cards have been set to Inactive.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to deactivate accounts', 'error');
        }
    }

    // ── Global Activate All ──
    async handleActivateAll() {
        if (!confirm('✅ This will REACTIVATE all Savings accounts and Cards for this customer. Continue?')) {
            return;
        }
        try {
            await reactivateAllAccountsAndCards({ accountId: this.selectedAccountId });
            this._showToast('All Activated', 'All savings accounts and cards have been reactivated.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to activate accounts', 'error');
        }
    }

    // ── Freeze / Reactivate Financial Account ──
    async handleFreezeAccount(event) {
        const faId = event.currentTarget.dataset.id;
        try {
            await freezeFinancialAccount({ financialAccountId: faId });
            this._showToast('Account Frozen', 'Financial account has been frozen successfully.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to freeze account', 'error');
        }
    }

    async handleReactivateAccount(event) {
        const faId = event.currentTarget.dataset.id;
        try {
            await reactivateFinancialAccount({ financialAccountId: faId });
            this._showToast('Account Reactivated', 'Financial account is now active.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to reactivate account', 'error');
        }
    }

    // ── Freeze / Reactivate Card ──
    async handleFreezeCard(event) {
        const cardId = event.currentTarget.dataset.id;
        try {
            await freezeCard({ cardId });
            this._showToast('Card Frozen', 'Card has been frozen successfully.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to freeze card', 'error');
        }
    }

    async handleReactivateCard(event) {
        const cardId = event.currentTarget.dataset.id;
        try {
            await reactivateCard({ cardId });
            this._showToast('Card Reactivated', 'Card is now active.', 'success');
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to reactivate card', 'error');
        }
    }

    // ── Transaction Dispute ──
    handleTransactionRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        if (action.name === 'file_dispute') {
            this.disputeTransaction = row;
            this.selectedDisputeType = '';
            this.disputeDescription = '';
            this.showDisputeModal = true;
        }
    }

    get disputeTypeOptions() {
        return [
            { label: 'Unauthorized Transaction', value: 'Unauthorized Transaction' },
            { label: 'Duplicate Charge', value: 'Duplicate Charge' },
            { label: 'Service Not Received', value: 'Service Not Received' },
            { label: 'Incorrect Amount', value: 'Incorrect Amount' },
            { label: 'Fraudulent Activity', value: 'Fraudulent Activity' }
        ];
    }

    get isDisputeSubmitDisabled() {
        return !this.selectedDisputeType || this.isDisputeSubmitting;
    }

    get disputeTxnAmount() {
        return this.disputeTransaction ? this._formatCurrency(this.disputeTransaction.FinServ__Amount__c) : '';
    }

    handleDisputeTypeChange(event) { this.selectedDisputeType = event.detail.value; }
    handleDisputeDescChange(event) { this.disputeDescription = event.detail.value; }
    handleDisputeModalClose() { this.showDisputeModal = false; this.disputeTransaction = null; }

    async handleDisputeSubmit() {
        this.isDisputeSubmitting = true;
        try {
            await fileTransactionDispute({
                transactionId: this.disputeTransaction.Id,
                accountId: this.selectedAccountId,
                disputeType: this.selectedDisputeType,
                description: this.disputeDescription
            });
            this._showToast('Dispute Filed', 'Case created — provisional credit of ' + this.disputeTxnAmount + ' issued. Resolution in 10 days.', 'success');
            this.showDisputeModal = false;
            this.disputeTransaction = null;
            this._loadDashboard(this.selectedAccountId);
        } catch (error) {
            this._showToast('Error', error.body?.message || 'Failed to file dispute', 'error');
        } finally {
            this.isDisputeSubmitting = false;
        }
    }

    // ── Utility ──
    _formatCurrency(value) {
        if (value == null) return '₹0';
        return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}