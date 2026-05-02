import { LightningElement, api, track } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import uploadFile from '@salesforce/apex/ZentraFileUploadController.uploadFile';

const MAX_FILE_SIZE = 4500000; // 4.5 MB
const ALLOWED_TYPES = [
    'image/jpeg', 'image/png', 'image/gif', 'image/bmp', 'image/webp',
    'image/heic', 'image/heif', 'application/pdf'
];

export default class ZentraFileUpload extends LightningElement {
    @api label = 'Upload Receipt / Screenshot';
    @api recordId;

    @track _contentDocumentId;

    @api
    get contentDocumentId() {
        return this._contentDocumentId;
    }
    set contentDocumentId(value) {
        this._contentDocumentId = value;
    }

    uploadedFileName;
    isUploading = false;
    errorMessage;

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        // Validate file type
        if (!ALLOWED_TYPES.includes(file.type)) {
            this.errorMessage = 'Unsupported file type. Please upload JPG, PNG, GIF, BMP, WebP, PDF, or HEIC.';
            return;
        }

        // Validate file size
        if (file.size > MAX_FILE_SIZE) {
            this.errorMessage = 'File is too large. Maximum size is 4.5 MB.';
            return;
        }

        this.errorMessage = null;
        this.isUploading = true;
        this.uploadedFileName = file.name;

        const reader = new FileReader();
        reader.onload = () => {
            // Strip the data URL prefix to get pure base64
            const base64 = reader.result.split(',')[1];
            this.doUpload(file.name, base64);
        };
        reader.onerror = () => {
            this.errorMessage = 'Failed to read file. Please try again.';
            this.isUploading = false;
            this.uploadedFileName = null;
        };
        reader.readAsDataURL(file);
    }

    doUpload(fileName, base64Data) {
        uploadFile({ fileName: fileName, base64Data: base64Data, recordId: this.recordId })
            .then(result => {
                this._contentDocumentId = result;
                this.isUploading = false;
                this.errorMessage = null;
                // Notify flow that the output value has changed
                this.dispatchEvent(new FlowAttributeChangeEvent('contentDocumentId', this._contentDocumentId));
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : 'Upload failed. Please try again.';
                this.isUploading = false;
                this.uploadedFileName = null;
                this._contentDocumentId = null;
            });
    }

    handleRemove() {
        this.uploadedFileName = null;
        this._contentDocumentId = null;
        this.errorMessage = null;
        // Reset file input
        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) fileInput.value = '';
        // Notify flow
        this.dispatchEvent(new FlowAttributeChangeEvent('contentDocumentId', null));
    }

    // Flow output validation
    @api
    validate() {
        if (!this._contentDocumentId) {
            return {
                isValid: false,
                errorMessage: 'Please upload a file before continuing.'
            };
        }
        return { isValid: true };
    }
}