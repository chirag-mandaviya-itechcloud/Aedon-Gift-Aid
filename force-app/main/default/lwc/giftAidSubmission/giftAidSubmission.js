import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/GiftAidSubmissionController.getTransactions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const columns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Paid Amount', fieldName: 'aednpc__Paid_Amount__c' }
]
export default class GiftAidSubmission extends NavigationMixin(LightningElement) {
    @track startDate;
    @track endDate;
    @track errorMessage = '';

    columns = columns;
    @track salesInvoiceTransactionData = [];
    selectedRowsIds = [];
    selectedRowsData = [];
    @track pageNumber = 1;
    @track pageSize = 10;
    @track totalPages = 0;
    @track singlePageSalesInvoiceTransactionData = [];
    selectedMap = new Map();

    connectedCallback() {
        this.loadTransactions();
    }

    loadTransactions() {
        getTransactions()
            .then(result => {
                this.salesInvoiceTransactionData = result;
                console.log('Transactions fetched: ', result);

                if (this.salesInvoiceTransactionData.length > 0) {
                    this.totalPages = Math.ceil(this.salesInvoiceTransactionData.length / this.pageSize);
                    this.pageNumber = 1;
                    this.setPageData();
                } else {
                    this.totalPages = 1;
                    this.pageNumber = 1;
                    this.singlePageSalesInvoiceTransactionData = [];
                }
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

                if (this.salesInvoiceTransactionData.length > 0) {
                    this.totalPages = Math.ceil(this.salesInvoiceTransactionData.length / this.pageSize);
                    this.pageNumber = 1;
                    this.setPageData();
                } else {
                    this.totalPages = 1;
                    this.pageNumber = 1;
                    this.singlePageSalesInvoiceTransactionData = [];
                }
                this.clearSelection();
            })
            .catch(error => {
                console.error('Error:', error);
            });
    }

    clearSelection() {
        this.selectedMap.clear();
        this.selectedRowsIds = [];
    }

    handleRowSelection(event) {
        const newlySelectedRows = event.detail.selectedRows;
        console.log
        const currentPageIds = this.singlePageSalesInvoiceTransactionData.map(row => row.Id);

        currentPageIds.forEach(id => {
            this.selectedMap.delete(id);
        })

        newlySelectedRows.forEach(row => {
            this.selectedMap.set(row.Id, row);
        })

        this.selectedRowsIds = Array.from(this.selectedMap.keys());

        // this.selectedRowsIds = this.selectedRowsIds.filter(id => !currentPageIds.includes(id));
        // const newIds = newlySelectedRows.map(row => row.Id);
        // this.selectedRowsIds = [...this.selectedRowsIds, ...newIds];

        // const allRows = [...this.selectedRowsData, ...newlySelectedRows];
        // const uniqueMap = new Map();
        // allRows.forEach(row => uniqueMap.set(row.Id, row));
        // this.selectedRowsData = Array.from(uniqueMap.values());

        console.log("Selected Row IDs:", this.selectedRowsIds);
        // console.log("Selected Rows Data:", this.selectedRowsData);
    }

    goToListView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'aednpc__Sales_Invoice_Transaction__c',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }

    handleClose() {
        this.goToListView();
    }

    handleSubmitAndClose() {
        this.goToListView();
    }

    handleSubmit() {

    }

    setPageData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = this.pageNumber * this.pageSize;
        this.singlePageSalesInvoiceTransactionData = this.salesInvoiceTransactionData.slice(start, end);

        this.selectedRowsIds = Array.from(this.selectedMap.keys());
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.setPageData();
        }
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.setPageData();
        }
    }

    get isPrevDisabled() {
        return this.pageNumber <= 1;
    }

    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    get totalSelected() {
        return this.selectedRowsIds.length;
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
