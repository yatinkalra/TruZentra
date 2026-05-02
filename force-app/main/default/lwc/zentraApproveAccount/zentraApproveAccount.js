import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import approveAndCreateAccount from '@salesforce/apex/ZentraSetupCustomer.approveAndCreateAccount';

import STATUS_FIELD from '@salesforce/schema/Case.Status';
import SUPPLIED_NAME from '@salesforce/schema/Case.SuppliedName';
import SUPPLIED_PHONE from '@salesforce/schema/Case.SuppliedPhone';
import SUPPLIED_EMAIL from '@salesforce/schema/Case.SuppliedEmail';
import RECORD_TYPE_NAME from '@salesforce/schema/Case.RecordType.DeveloperName';

const FIELDS = [STATUS_FIELD, SUPPLIED_NAME, SUPPLIED_PHONE, SUPPLIED_EMAIL, RECORD_TYPE_NAME];

export default class ZentraApproveAccount extends NavigationMixin(LightningElement) {
    @api recordId;
    isModalOpen = false;
    includeTestData = true;
    isProcessing = false;
    caseInfo = null;
    showButton = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ data, error }) {
        if (data) {
            const rtName = getFieldValue(data, RECORD_TYPE_NAME);
            const status = getFieldValue(data, STATUS_FIELD);
            this.showButton = rtName === 'New_Account_Opening' && status !== 'Approved' && status !== 'Closed';
            this.caseInfo = {
                SuppliedName: getFieldValue(data, SUPPLIED_NAME) || 'N/A',
                SuppliedPhone: getFieldValue(data, SUPPLIED_PHONE) || 'N/A',
                SuppliedEmail: getFieldValue(data, SUPPLIED_EMAIL) || 'N/A'
            };
        }
        if (error) {
            this.showButton = false;
        }
    }

    get submitLabel() {
        return this.isProcessing ? 'Processing...' : 'Approve & Create';
    }

    handleOpenModal() {
        this.isModalOpen = true;
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleTestDataToggle(event) {
        this.includeTestData = event.target.checked;
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
            this.isModalOpen = false;
            this.showButton = false;
            // Refresh the record page
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