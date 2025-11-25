import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/GiftAidSubmissionController.getTransactions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import saveSubmission from '@salesforce/apex/GiftAidSubmissionController.saveSubmission';

const columns = [
    { label: 'Sales Header', fieldName: 'salesInvoiceHeaderName' },
    { label: 'Name', fieldName: 'Name' },
    { label: 'Company', fieldName: 'companyName' },
    { label: 'Invoice Date', fieldName: 'invoiceDate', type: 'date' },
    { label: 'Account Name', fieldName: 'accountName' },
    { label: 'Customer Reference', fieldName: 'aednpc__Customer_Reference__c' },
    { label: 'Product Name', fieldName: 'productName' },
    { label: 'Nominal Code', fieldName: 'nominalCode' },
    { label: 'Sales VAT', fieldName: 'salesVAT' },
    { label: 'Analysis 1', fieldName: 'analysis1' },
    { label: 'Analysis 2', fieldName: 'analysis2' },
    // { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Paid Amount', fieldName: 'paid_amount__c' },
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
                    salesInvoiceHeaderName: record.aednpc__Sales_Invoice_Header__r?.Name,
                    companyName: record.aednpc__Company__r?.Name,
                    invoiceDate: record.aednpc__Sales_Invoice_Header__r?.aednpc__Invoice_Date__c,
                    accountName: record.aednpc__Sales_Invoice_Header__r?.aednpc__Account__r?.Name,
                    productName: record.aednpc__Product__r?.Name,
                    nominalCode: record.aednpc__Nominal_Code2__r?.aednpc__Nominal_Code__c,
                    salesVAT: record.aednpc__Sale_VAT__r?.Name,
                    analysis1: record.aednpc__Analysis_1__r?.Name,
                    analysis2: record.aednpc__Analysis_2__r?.Name,
                    paid_amount__c: Number(record.aednpc__Paid_Amount__c).toFixed(2)
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
                    salesInvoiceHeaderName: record.aednpc__Sales_Invoice_Header__r?.Name,
                    companyName: record.aednpc__Company__r?.Name,
                    invoiceDate: record.aednpc__Sales_Invoice_Header__r?.aednpc__Invoice_Date__c,
                    accountName: record.aednpc__Sales_Invoice_Header__r?.aednpc__Account__r?.Name,
                    productName: record.aednpc__Product__r?.Name,
                    nominalCode: record.aednpc__Nominal_Code2__r?.aednpc__Nominal_Code__c,
                    salesVAT: record.aednpc__Sale_VAT__r?.Name,
                    analysis1: record.aednpc__Analysis_1__r?.Name,
                    analysis2: record.aednpc__Analysis_2__r?.Name,
                    paid_amount__c: Number(record.aednpc__Paid_Amount__c).toFixed(2)
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

    async handleSubmitAndClose() {
        const ok = await this.handleSubmit();

        if (!ok) {
            return;
        }
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
