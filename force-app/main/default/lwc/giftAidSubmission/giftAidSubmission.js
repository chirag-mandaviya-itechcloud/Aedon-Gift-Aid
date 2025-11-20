import { LightningElement, track } from 'lwc';

const columns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Paid Amount', fieldName: 'Paid_Amount__c' }
]
export default class GiftAidSubmission extends LightningElement {
    @track startDate;
    @track endDate;
    @track errorMessage = '';

    columns = columns;
    @track SalesInvoiceTransactionData = [];
    @track selectedRows = [];

    handleDateChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;

        if (fieldName === 'startDate') {
            this.startDate = fieldValue;
        }
        if (fieldName === 'endDate') {
            this.endDate = fieldValue;
        }

        this.validateDates();
    }

    validateDates() {
        this.errorMessage = '';

        if (this.startDate && this.endDate && this.startDate > this.endDate) {
            this.errorMessage = 'Start date cannot be greater than end date.';
            return;
        }
    }
}
