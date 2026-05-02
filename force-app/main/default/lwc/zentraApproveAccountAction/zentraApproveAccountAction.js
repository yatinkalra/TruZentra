import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import approveAndCreateAccount from '@salesforce/apex/ZentraSetupCustomer.approveAndCreateAccount';

import STATUS_FIELD from '@salesforce/schema/Case.Status';
import SUPPLIED_NAME from '@salesforce/schema/Case.SuppliedName';
import SUPPLIED_PHONE from '@salesforce/schema/Case.SuppliedPhone';
import SUPPLIED_EMAIL from '@salesforce/schema/Case.SuppliedEmail';
import RECORD_TYPE_NAME from '@salesforce/schema/Case.RecordType.DeveloperName';

const FIELDS = [STATUS_FIELD, SUPPLIED_NAME, SUPPLIED_PHONE, SUPPLIED_EMAIL, RECORD_TYPE_NAME];

export default class ZentraApproveAccountAction extends LightningElement {
    @api recordId;
    includeTestData = true;
    isProcessing = false;
    isLoading = true;
    caseInfo = null;
    caseStatus = '';
    alreadyProcessed = false;
    showForm = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ data, error }) {
        this.isLoading = false;
        if (data) {
            const status = getFieldValue(data, STATUS_FIELD);
            this.caseStatus = status;

            if (status === 'Approved' || status === 'Closed') {
                this.alreadyProcessed = true;
                this.showForm = false;
            } else {
                this.alreadyProcessed = false;
                this.showForm = true;
            }

            this.caseInfo = {
                SuppliedName: getFieldValue(data, SUPPLIED_NAME) || 'N/A',
                SuppliedPhone: getFieldValue(data, SUPPLIED_PHONE) || 'N/A',
                SuppliedEmail: getFieldValue(data, SUPPLIED_EMAIL) || 'N/A'
            };
        }
        if (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Unable to load case details.',
                variant: 'error'
            }));
            this.handleClose();
        }
    }

    get submitLabel() {
        return this.isProcessing ? 'Processing...' : 'Approve & Create Account';
    }

    handleTestDataToggle(event) {
        this.includeTestData = event.target.checked;
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleApprove() {
        this.isProcessing = true;
        try {
            const result = await approveAndCreateAccount({
                caseId: this.recordId,
                includeTestData: this.includeTestData
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Account Created',
                message: result,
                variant: 'success'
            }));
            this.handleClose();
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            const msg = error.body ? error.body.message : error.message;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: msg,
                variant: 'error'
            }));
        } finally {
            this.isProcessing = false;
        }
    }
}