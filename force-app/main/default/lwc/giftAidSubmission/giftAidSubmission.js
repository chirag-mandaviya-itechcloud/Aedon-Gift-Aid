import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/GiftAidSubmissionController.getTransactions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const columns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Paid Amount', fieldName: 'aednpc__Paid_Amount__c' }
]
export default class GiftAidSubmission extends LightningElement {
    @track startDate;
    @track endDate;
    @track errorMessage = '';

    columns = columns;
    salesInvoiceTransactionData = [];
    selectedRows = [];

    connectedCallback() {
        this.loadTransactions();
    }

    loadTransactions() {
        getTransactions()
            .then(result => {
                this.salesInvoiceTransactionData = result;
                console.log('Transactions fetched: ', result);
            })
            .catch(error => {
                console.error('Error fetching transactions: ', error);
            });
    }

    handleDateChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.target.value;

        if (fieldName === 'startDate') {
            this.startDate = fieldValue;
        }
        if (fieldName === 'endDate') {
            this.endDate = fieldValue;
        }

        console.log(`Date changed - ${fieldName}: ${fieldValue}`);
    }

    handleFilter() {
        if (!this.startDate || !this.endDate) {
            this.showToast('Warning', 'Please fill the Dates', 'warning');
            return;
        }

        if (this.startDate > this.endDate) {
            this.showToast('Warning', 'Start date cannot be greater than end date.', 'warning');
            return;
        }

        const startDateTime = this.getStartOfDay(this.startDate);
        const endDateTime = this.getEndOfDay(this.endDate);

        getTransactions({
            startDate: startDateTime,
            endDate: endDateTime
        })
            .then(result => {
                this.salesInvoiceTransactionData = result;
                console.log('Filtered transactions: ', result);
            })
            .catch(error => {
                console.error('Error:', error);
            });
    }

    handleRowSelection(event) {
        console.log('Row selection changed: ', event.detail.selectedRows);
        this.selectedRows = event.detail.selectedRows;
    }

    getStartOfDay(dateString) {
        let dt = new Date(dateString);
        dt.setHours(0, 0, 0, 0);
        return dt.toISOString();
    }

    getEndOfDay(dateString) {
        let dt = new Date(dateString);
        dt.setHours(23, 59, 59, 999);
        return dt.toISOString();
    }

    showToast(mTitle, mMessage, mVariant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: mTitle,
                message: mMessage,
                variant: mVariant
            }),
        )
    }
}
