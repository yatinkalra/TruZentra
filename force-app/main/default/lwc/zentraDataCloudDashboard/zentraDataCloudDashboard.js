import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAccounts from '@salesforce/apex/ZentraDataCloudController.searchAccounts';
import getDashboardData from '@salesforce/apex/ZentraDataCloudController.getDashboardData';
import getChurnInsight from '@salesforce/apex/ZentraDataCloudController.getChurnInsight';

const LOAN_TYPES = new Set(['Loan Account', 'Auto Loan', 'Mortgage']);
const ICON_MAP = { 'Savings Account': 'utility:moneybag', 'Credit Card': 'utility:budget_category_value',
    'Loan Account': 'utility:money', 'Auto Loan': 'utility:travel_and_places', 'Mortgage': 'utility:home' };
const LIMITS = { fa: 3, txn: 5, rp: 3, loan: 3, dispute: 3 };

export default class ZentraDataCloudDashboard extends LightningElement {
    searchTerm = '';
    searchResults = [];
    showSearchResults = false;
    noSearchResults = false;
    isLoading = false;
    dashboardData = null;
    selectedAccountId = null;
    selectedAccountName = '';
    churnInsight = null;
    _searchTimeout;

    // ── Show-more toggles ──
    _expanded = { fa: false, txn: false, rp: false, loan: false, dispute: false };

    // ── States ──
    get showEmptyState() { return !this.isLoading && !this.dashboardData; }
    get hasData() { return !!this.dashboardData; }

    // ── Profile Sidebar ──
    get accountInitials() {
        const n = this.dashboardData?.account?.Name || '';
        return n.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
    }
    get contactEmail() { return this.dashboardData?.account?.PersonEmail || '—'; }
    get contactPhone() { return this.dashboardData?.account?.Phone || this.dashboardData?.account?.PersonMobilePhone || '—'; }
    get accountUrl() { return '/' + this.dashboardData?.account?.Id; }
    get memberSince() {
        const d = this.dashboardData?.account?.CreatedDate;
        return d ? new Date(d).toLocaleDateString('en-IN', { month: 'short', year: 'numeric' }) : '—';
    }

    // ── Sidebar Quick Stats ──
    get totalBalance() {
        const total = (this.dashboardData?.financialAccounts || [])
            .filter(fa => !LOAN_TYPES.has(fa.FinancialAccountType))
            .reduce((sum, fa) => sum + (fa.Balance || 0), 0);
        return this._formatCurrency(total);
    }
    get totalLiability() {
        const total = (this.dashboardData?.financialAccounts || [])
            .filter(fa => LOAN_TYPES.has(fa.FinancialAccountType))
            .reduce((sum, fa) => sum + (fa.PrincipalBalance || fa.LoanAmount || 0), 0);
        return this._formatCurrency(total);
    }
    get totalFinancialAccounts() { return this.dashboardData?.financialAccounts?.length || 0; }
    get activeRecurringCount() {
        return (this.dashboardData?.recurringPayments || []).filter(r => r.Status === 'Active').length;
    }
    get openDisputeCount() {
        return (this.dashboardData?.disputeCases || []).filter(c => c.DisputeStage !== 'Resolved' && c.DisputeStage !== 'Rejected').length;
    }

    // ── Calculated Insight: Churn Risk (from Zentra_Customer_Churn_Risk__cio) ──
    get insightCards() {
        if (!this.dashboardData) return [];
        const ci = this.churnInsight;

        let churnValue, churnSub, churnColor;
        if (ci && ci.available) {
            const score = ci.churnRiskScore || 0;
            const level = score >= 50 ? 'High' : score >= 25 ? 'Medium' : 'Low';
            churnColor = score >= 50 ? 'insight-val-red' : score >= 25 ? 'insight-val-amber' : 'insight-val-green';
            churnValue = score + '/80';
            churnSub = level + ' Risk';
        } else {
            churnValue = 'Not Available';
            churnSub = 'CI not loaded';
            churnColor = 'insight-val-grey';
        }

        return [
            {
                key: 'churn', icon: 'utility:warning',
                title: 'Churn Risk',
                value: churnValue, subtitle: churnSub,
                valueClass: 'insight-val ' + churnColor,
                cardClass: 'insight-card insight-churn'
            }
        ];
    }
    get hasInsights() { return this.insightCards.length > 0; }

    // ── Has-data flags ──
    get hasFinancialAccounts() { return this.totalFinancialAccounts > 0; }
    get hasTransactions() { return (this.dashboardData?.recentTransactions?.length || 0) > 0; }
    get hasRecurringPayments() { return (this.dashboardData?.recurringPayments?.length || 0) > 0; }
    get hasLoanRequests() { return (this.dashboardData?.loanRestructuringRequests?.length || 0) > 0; }
    get hasDisputes() { return (this.dashboardData?.disputeCases?.length || 0) > 0; }

    // ── Visible slices + show-more flags ──
    get visibleFinancialCards() {
        const all = this.financialAccountCards;
        return this._expanded.fa ? all : all.slice(0, LIMITS.fa);
    }
    get showMoreFa() { return !this._expanded.fa && (this.financialAccountCards.length > LIMITS.fa); }
    get showLessFa() { return this._expanded.fa && (this.financialAccountCards.length > LIMITS.fa); }
    get moreCountFa() { return this.financialAccountCards.length - LIMITS.fa; }

    get visibleTransactions() {
        const all = this.transactionTimeline;
        return this._expanded.txn ? all : all.slice(0, LIMITS.txn);
    }
    get showMoreTxn() { return !this._expanded.txn && (this.transactionTimeline.length > LIMITS.txn); }
    get showLessTxn() { return this._expanded.txn && (this.transactionTimeline.length > LIMITS.txn); }
    get moreCountTxn() { return this.transactionTimeline.length - LIMITS.txn; }

    get visibleRecurring() {
        const all = this.recurringCards;
        return this._expanded.rp ? all : all.slice(0, LIMITS.rp);
    }
    get showMoreRp() { return !this._expanded.rp && (this.recurringCards.length > LIMITS.rp); }
    get showLessRp() { return this._expanded.rp && (this.recurringCards.length > LIMITS.rp); }
    get moreCountRp() { return this.recurringCards.length - LIMITS.rp; }

    get visibleLoans() {
        const all = this.loanCards;
        return this._expanded.loan ? all : all.slice(0, LIMITS.loan);
    }
    get showMoreLoan() { return !this._expanded.loan && (this.loanCards.length > LIMITS.loan); }
    get showLessLoan() { return this._expanded.loan && (this.loanCards.length > LIMITS.loan); }
    get moreCountLoan() { return this.loanCards.length - LIMITS.loan; }

    get visibleDisputes() {
        const all = this.disputeCards;
        return this._expanded.dispute ? all : all.slice(0, LIMITS.dispute);
    }
    get showMoreDispute() { return !this._expanded.dispute && (this.disputeCards.length > LIMITS.dispute); }
    get showLessDispute() { return this._expanded.dispute && (this.disputeCards.length > LIMITS.dispute); }
    get moreCountDispute() { return this.disputeCards.length - LIMITS.dispute; }

    handleToggle(event) {
        const section = event.currentTarget.dataset.section;
        this._expanded = { ...this._expanded, [section]: !this._expanded[section] };
    }

    // ── Financial Account Cards ──
    get financialAccountCards() {
        return (this.dashboardData?.financialAccounts || []).map(fa => {
            const t = fa.FinancialAccountType;
            const isLoan = LOAN_TYPES.has(t);
            const isCC = t === 'Credit Card';
            const bal = isLoan ? (fa.PrincipalBalance || fa.LoanAmount || 0) : (fa.Balance || 0);
            const cls = t === 'Savings Account' ? 'fac fac-savings' : isCC ? 'fac fac-credit' : 'fac fac-loan';
            return {
                ...fa, isLoan, isCreditCard: isCC, isSavings: t === 'Savings Account',
                icon: ICON_MAP[t] || 'utility:money',
                cardClass: cls,
                displayBalance: this._formatCurrency(bal),
                statusPill: fa.Status === 'Active' ? 'pill pill-green' : 'pill pill-grey',
                emiDisplay: this._formatCurrency(fa.CurrentEMI || 0),
                rateDisplay: (fa.InterestRate || 0).toFixed(1) + '%',
                tenureDisplay: (fa.LoanTermMonths || 0) + ' months',
                creditUsed: fa.TotalCreditLimit ? this._formatCurrency((fa.TotalCreditLimit || 0) - (fa.AvailableCredit || 0)) : '—',
                creditLimit: this._formatCurrency(fa.TotalCreditLimit || 0),
                branchDisplay: fa.BranchName || '—'
            };
        });
    }

    // ── Transaction Timeline ──
    get transactionTimeline() {
        return (this.dashboardData?.recentTransactions || []).map(tx => {
            const amt = tx.Amount || 0;
            return {
                ...tx,
                amountDisplay: this._formatCurrency(Math.abs(amt)),
                amountClass: amt < 0 ? 'txn-amount txn-debit' : 'txn-amount txn-credit',
                sign: amt < 0 ? '-' : '+',
                dateDisplay: tx.TransactionDate
                    ? new Date(tx.TransactionDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })
                    : '—',
                descDisplay: tx.Description || tx.MerchantName || 'Transaction',
                categoryPill: tx.Category || 'General'
            };
        });
    }

    // ── Recurring Payment Cards ──
    get recurringCards() {
        return (this.dashboardData?.recurringPayments || []).map(rp => ({
            ...rp,
            amountDisplay: this._formatCurrency(rp.Amount || 0),
            statusPill: rp.Status === 'Active' ? 'pill pill-green' : rp.Status === 'Stopped' ? 'pill pill-red' : 'pill pill-grey',
            nextDisplay: rp.NextPaymentDate
                ? new Date(rp.NextPaymentDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                : '—'
        }));
    }

    // ── Loan Request Cards ──
    get loanCards() {
        return (this.dashboardData?.loanRestructuringRequests || []).map(lr => ({
            ...lr,
            originalDisplay: this._formatCurrency(lr.OriginalEMI || 0),
            newDisplay: this._formatCurrency(lr.NewEMI || 0),
            savingsDisplay: this._formatCurrency(lr.MonthlySavings || 0),
            statusPill: lr.Status === 'Approved' ? 'pill pill-green' : lr.Status === 'Pending' ? 'pill pill-amber' : 'pill pill-grey',
            dateDisplay: lr.CreatedDate
                ? new Date(lr.CreatedDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                : '—'
        }));
    }

    // ── Dispute Cards ──
    get disputeCards() {
        return (this.dashboardData?.disputeCases || []).map(dc => ({
            ...dc,
            amountDisplay: this._formatCurrency(dc.DisputeAmount || 0),
            creditDisplay: dc.ProvisionalCreditAmount ? this._formatCurrency(dc.ProvisionalCreditAmount) : '—',
            stagePill: dc.DisputeStage === 'Resolved' ? 'pill pill-green'
                : dc.DisputeStage === 'Rejected' ? 'pill pill-red' : 'pill pill-amber',
            dateDisplay: dc.CreatedDate
                ? new Date(dc.CreatedDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                : '—',
            resDisplay: dc.EstimatedResolutionDate
                ? new Date(dc.EstimatedResolutionDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                : '—'
        }));
    }

    // ── Search ──
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
        this._searchTimeout = setTimeout(() => this._doSearch(val), 300);
    }
    async _doSearch(term) {
        try {
            const results = await searchAccounts({ searchTerm: term });
            this.searchResults = results;
            this.showSearchResults = true;
            this.noSearchResults = results.length === 0;
        } catch (e) {
            this.searchResults = [];
            this.showSearchResults = false;
        }
    }
    handleAccountSelect(event) {
        this.selectedAccountId = event.currentTarget.dataset.id;
        this.selectedAccountName = event.currentTarget.dataset.name;
        this.searchTerm = '';
        this.searchResults = [];
        this.showSearchResults = false;
        this.noSearchResults = false;
        this._loadDashboard(this.selectedAccountId);
    }
    handleRefresh() {
        if (this.selectedAccountId) {
            this._loadDashboard(this.selectedAccountId);
            this._showToast('Refreshing', 'Reloading from Data Cloud...', 'info');
        }
    }
    handleClearSelection() {
        this.selectedAccountId = null;
        this.selectedAccountName = '';
        this.dashboardData = null;
        this.churnInsight = null;
        this.searchTerm = '';
        this._expanded = { fa: false, txn: false, rp: false, loan: false, dispute: false };
    }
    async _loadDashboard(accountId) {
        this.isLoading = true;
        this.dashboardData = null;
        try {
            const [dashboard, churn] = await Promise.all([
                getDashboardData({ accountId }),
                getChurnInsight({ accountId }).catch(() => ({ available: false }))
            ]);
            this.dashboardData = dashboard;
            this.churnInsight = churn;
        } catch (e) {
            this._showToast('Error', e.body?.message || 'Failed to load Data Cloud data', 'error');
            this.dashboardData = null;
        } finally {
            this.isLoading = false;
        }
    }

    // ── Utility ──
    _formatCurrency(v) {
        if (v == null) return '₹0';
        return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
    }
    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
