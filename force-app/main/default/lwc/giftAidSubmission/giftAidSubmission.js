import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/GiftAidSubmissionController.getTransactions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import saveSubmission from '@salesforce/apex/GiftAidSubmissionController.saveSubmission';

const columns = [
    { label: 'Sales Header', fieldName: 'salesInvoiceHeaderName', initialWidth: 150 },
    // { label: 'Name', fieldName: 'name', initialWidth: 150 },
    { label: 'Company', fieldName: 'companyName', initialWidth: 150 },
    { label: 'Invoice Date', fieldName: 'invoiceDate', type: 'date', initialWidth: 150 },
    { label: 'Account Name', fieldName: 'accountName', initialWidth: 150 },
    { label: 'First Name', fieldName: 'contactFirstName', initialWidth: 150 },
    { label: 'Last Name', fieldName: 'contactLastName', initialWidth: 150 },
    { label: 'Postal Code', fieldName: 'contactPostalCode', initialWidth: 150 },
    { label: 'Customer Reference', fieldName: 'customerReference', initialWidth: 150 },
    { label: 'Product Name', fieldName: 'productName', initialWidth: 150 },
    { label: 'Nominal Code', fieldName: 'nominalCode', initialWidth: 150 },
    { label: 'Sales VAT', fieldName: 'salesVAT', initialWidth: 150 },
    { label: 'Paid Amount', fieldName: 'paidAmount', initialWidth: 150 },
    { label: 'Analysis 1', fieldName: 'analysis1', initialWidth: 150 },
    { label: 'Analysis 2', fieldName: 'analysis2', initialWidth: 150 },
    { label: 'Analysis 6', fieldName: 'analysis6', initialWidth: 150 },
    { label: 'Analysis 7', fieldName: 'analysis7', initialWidth: 150 },
]
export default class GiftAidSubmission extends NavigationMixin(LightningElement) {
    @track startDate = null;
    @track endDate = null;
    @track errorMessage = '';
    @track isLoading = false;

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
        this.isLoading = true;
        getTransactions()
            .then(result => {
                console.log('Transactions fetched: ', result);
                this.salesInvoiceTransactionData = result.map(record => ({
                    ...record,
                    paidAmount: Number(record.paidAmount).toFixed(2)
                }));

                if (this.salesInvoiceTransactionData.length > 0) {
                    this.totalPages = Math.ceil(this.salesInvoiceTransactionData.length / this.pageSize);
                    this.pageNumber = 1;
                    this.setPageData();
                } else {
                    this.totalPages = 1;
                    this.pageNumber = 1;
                    this.singlePageSalesInvoiceTransactionData = [];
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching transactions: ', error);
                this.isLoading = false;
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
            this.showToast('Error', 'Please fill the Dates', 'error');
            return;
        }

        if (this.startDate > this.endDate) {
            this.showToast('Error', 'Start date cannot be greater than end date.', 'error');
            return;
        }

        // const startDateTime = this.getStartOfDay(this.startDate);
        // const endDateTime = this.getEndOfDay(this.endDate);

        this.isLoading = true;

        getTransactions({
            startDate: this.startDate,
            endDate: this.endDate
        })
            .then(result => {
                console.log('Filtered transactions: ', result);
                this.salesInvoiceTransactionData = result.map(record => ({
                    ...record,
                    paidAmount: Number(record.paidAmount).toFixed(2)
                }));

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
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error:', error);
                this.isLoading = false;
            });
    }

    handleClearFilter() {
        this.startDate = null;
        this.endDate = null;
        this.loadTransactions();
    }

    clearSelection() {
        this.selectedMap.clear();
        this.selectedRowsIds = [];
    }

    resetFilters() {
        this.startDate = null;
        this.endDate = null;
        this.clearSelection();
        this.loadTransactions();
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
        this.resetFilters();
        setTimeout(() => {
            this.goToListView();
        }, 100);
    }

    async handleSubmitAndClose() {
        const ok = await this.handleSubmit();

        if (!ok) {
            return;
        }
        this.resetFilters();
        setTimeout(() => {
            this.goToListView();
        }, 1500);
    }

    async handleSubmit() {
        if (!this.selectedRowsIds || this.selectedRowsIds.length === 0) {
            this.showToast('Error', 'Please select the Transaction.', 'error');
            return false;
        }

        this.isLoading = true;

        try {
            const result = await saveSubmission({ salesTransactionIds: this.selectedRowsIds });
            console.log("result : ", result);
            this.showToast("Success", "Gift Aid Submission completed successfully.", "success");
            this.isLoading = false;
            if (this.startDate != null && this.endDate != null) {
                this.handleFilter();
            } else {
                this.loadTransactions();
            }
            this.clearSelection();
            return true;
        } catch (error) {
            console.error("Error : ", error);
            this.isLoading = false;
            return false;
        }
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