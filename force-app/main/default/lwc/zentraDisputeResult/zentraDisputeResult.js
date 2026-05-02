import { LightningElement, api } from 'lwc';

export default class ZentraDisputeResult extends LightningElement {
    @api caseNumber = '';
    @api disputeAmount = '';
    @api estimatedResolution = '';
    @api aiAnalysis = '';

    get formattedAmount() {
        if (!this.disputeAmount) return '';
        return '\u20B9' + this.disputeAmount;
    }

    handleClose() {
        try {
            window.close();
        } catch (e) {
            // Some browsers block window.close() if not opened by script
        }
        // Fallback: navigate to a blank page
        try {
            window.location.href = 'about:blank';
        } catch (e) { /* ignore */ }
    }
}