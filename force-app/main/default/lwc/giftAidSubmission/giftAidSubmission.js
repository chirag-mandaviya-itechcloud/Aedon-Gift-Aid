/**
 * giftAidSubmission LWC
 *
 * Author: Abhishek D
 * Created Date: 2025-11-22
 * Last Modified By: Abhishek D
 * Last Modified Date: 2025-12-18
 *
 * Purpose:
 *  - UI to list and select Sales Invoice Transactions for Gift Aid submission.
 *  - Allows filtering by date range, pagination, multi-page selection, and submission to Apex.
 *
 * Key integrations:
 *  - Apex: GiftAidSubmissionController.getTransactions, GiftAidSubmissionController.saveSubmission
 *  - NavigationMixin for navigation and ShowToastEvent for user notifications.
 *
 * Notes:
 *  - Date inputs expect 'YYYY-MM-DD' strings.
 *  - selectedRowsIds maintains selections across pages using selectedMap.
 */

import { LightningElement, track } from 'lwc';
import getTransactions from '@salesforce/apex/GiftAidSubmissionController.getTransactions';
import getProductFilterOptions from '@salesforce/apex/GiftAidSubmissionController.getProductFilterOptions';
import getGiftAidStatusOptions from '@salesforce/apex/GiftAidSubmissionController.getGiftAidStatusOptions';
import getCompanyFilterOptions from '@salesforce/apex/GiftAidSubmissionController.getCompanyFilterOptions';
import getCurrentUserCompany from '@salesforce/apex/GiftAidSubmissionController.getCurrentUserCompany';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import saveSubmission from '@salesforce/apex/GiftAidSubmissionController.saveSubmission';

const columns = [
    { label: 'Invoice Date', fieldName: 'invoiceDate', type: 'date', initialWidth: 150 },
    { label: 'Customer Reference', fieldName: 'customerReference', initialWidth: 150 },
    { label: 'Sales Header', fieldName: 'salesInvoiceHeaderName', initialWidth: 150 },
    { label: 'Company', fieldName: 'companyName', initialWidth: 150 },
    { label: 'Account Name', fieldName: 'accountName', initialWidth: 150 },
    { label: 'First Name', fieldName: 'contactFirstName', initialWidth: 150 },
    { label: 'Last Name', fieldName: 'contactLastName', initialWidth: 150 },
    { label: 'Postal Code', fieldName: 'contactPostalCode', initialWidth: 150 },
    { label: 'Product Name', fieldName: 'productName', initialWidth: 150 },
    { label: 'Nominal Code', fieldName: 'nominalCode', initialWidth: 150 },
    { label: 'Sales VAT', fieldName: 'salesVAT', initialWidth: 150 },
    { label: 'Paid Amount', fieldName: 'paidAmount', initialWidth: 150 },
    { label: 'Analysis 1', fieldName: 'analysis1', initialWidth: 150 },
    { label: 'Analysis 2', fieldName: 'analysis2', initialWidth: 150 },
    { label: 'Analysis 6', fieldName: 'analysis6', initialWidth: 150 },
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

    @track productOptions = [];
    @track giftAidStatusOptions = [];
    @track companyOptions = []; 
    @track selectedProduct = '';
    @track selectedGiftAidStatus = '';
    @track selectedGiftAidStatus = 'Non-Submitted';
    @track selectedCompany = '';

    defaultCompanyId = null;
    defaultCompanyName = null;

    /**
     * Lifecycle hook invoked when component is inserted into DOM.
     * Purpose: initialize component data by loading transactions.
     */
    connectedCallback() {
        this.loadCurrentUserCompany();
        this.loadTransactionsWithDefaultFilter();
        this.loadProductOptions();
        this.loadGiftAidStatusOptions();
        this.loadCompanyOptions();
    }

    /**
     * Load current logged-in user's company
     * Purpose: Get default company for filter, treat as null if not found
     */
    loadCurrentUserCompany() {
        this.isLoading = true;
        getCurrentUserCompany()
            .then(result => {
                console.log('Current User Company Result: ', result);
                
                // Check if result has companyId
                if (result && result.companyId) {
                    this.defaultCompanyId = result.companyId;
                    this.defaultCompanyName = result.companyName;
                    this.selectedCompany = result.companyId; // Set default selected company
                    console.log('Default Company Set: ' + this.defaultCompanyName + ' (' + this.defaultCompanyId + ')');
                } else {
                    // No company found - treat as null filter
                    this.defaultCompanyId = null;
                    this.defaultCompanyName = null;
                    this.selectedCompany = ''; // Empty string = no filter
                    console.log('No default company found for user. Company filter will be null.');
                }
                
                // Now load all other options and data
                this.loadProductOptions();
                this.loadGiftAidStatusOptions();
                this.loadCompanyOptions();
                this.loadTransactionsWithDefaultFilter();
            })
            .catch(error => {
                console.error('Error fetching current user company: ', error);
                
                // On error, treat as no company - null filter
                this.defaultCompanyId = null;
                this.defaultCompanyName = null;
                this.selectedCompany = '';
                console.log('Error loading company. Company filter will be null.');
                
                this.showToast('Info', 'Loading transactions without company filter', 'info');
                
                // Continue loading without default company
                this.loadProductOptions();
                this.loadGiftAidStatusOptions();
                this.loadCompanyOptions();
                this.loadTransactionsWithDefaultFilter();
            });
    }

    loadProductOptions() {
        this.isLoading = true;
        getProductFilterOptions()
            .then(result => {
                console.log('Product Filter Options: ', result);
                this.productOptions = result.map(item => ({
                    label: item.Name,
                    value: item.Id
                }));
                this.isLoading = false;
                console.log('Mapped Product Options: ', this.productOptions);
            })
            .catch(error => {
                console.error('Error fetching product options: ', error);
                this.isLoading = false;
            });
    }

    loadGiftAidStatusOptions() {
        getGiftAidStatusOptions()
            .then(result => {
                console.log('Gift Aid Status Options: ', result);
                this.giftAidStatusOptions = [
                    { label: '--None--', value: '' },
                    ...result.map(item => ({
                        label: item.label,
                        value: item.value
                    }))
                ];
                console.log('Mapped Gift Aid Status Options: ', this.giftAidStatusOptions);
            })
            .catch(error => {
                console.error('Error fetching gift aid status options: ', error);
                this.showToast('Error', 'Failed to load status options', 'error');
            });
    }

    loadCompanyOptions() {
        getCompanyFilterOptions()
            .then(result => {
                console.log('Company Filter Options: ', result);
                this.companyOptions = [
                    { label: '--None--', value: '' },
                    ...result.map(item => ({
                        label: item.Name,
                        value: item.Id
                    }))
                ];
                console.log('Mapped Company Options: ', this.companyOptions);
            })
            .catch(error => {
                console.error('Error fetching company options: ', error);
                this.showToast('Error', 'Failed to load company options', 'error');
            });
    }

    get selectedBadgeLabel() {
        return `${this.totalSelected} Selected`;
    }

    /**
     * Load transactions with default "Non-Submitted" filter
     * Purpose: Initial load with default submission status filter applied
     */
    loadTransactionsWithDefaultFilter() {
        this.isLoading = true;
        getTransactions({
            startDate: null,
            endDate: null,
            productId: null,
            giftAidStatus: 'Non-Submitted',
            companyId: this.selectedCompany
        })
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
                this.showToast('Error', 'Failed to load transactions', 'error');
                this.isLoading = false;
            });
    }

    /**
     * Load transactions from Apex.
     * Purpose: fetch transactions, format paidAmount, initialize pagination and manage loading state.
     */
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

    /**
     * Handle date input changes.
     * Params: event - input change event (expects name 'startDate' or 'endDate').
     * Purpose: update component date fields.
     */
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

    handleComboboxChange(event) {
        const fieldName = event.target.name;
        const fieldValue = event.detail.value;

        if (fieldName === 'productFilter') {
            this.selectedProduct = fieldValue;
        } else if (fieldName === 'giftAidStatusFilter') {
            this.selectedGiftAidStatus = fieldValue;
        } else if (fieldName === 'companyFilter') {
            this.selectedCompany = fieldValue;
        }

        console.log(`Filter changed - ${fieldName}: ${fieldValue}`);
    }

    /**
     * Apply date filter and reload transactions from Apex.
     * Purpose: validate dates, call getTransactions with date range, reset selection and update pagination.
     */
    handleFilter() {

        if (this.startDate && this.endDate && this.startDate > this.endDate) {
            this.showToast('Error', 'Start date cannot be greater than end date.', 'error');
            return;
        }

        this.isLoading = true;

        getTransactions({
            startDate: this.startDate,
            endDate: this.endDate,
            productId: this.selectedProduct,
            giftAidStatus: this.selectedGiftAidStatus,
            companyId: this.selectedCompany
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

    /**
     * Clear filter fields and reload all transactions.
     */
    handleClearFilter() {
        this.startDate = null;
        this.endDate = null;
        this.selectedProduct = '';
        this.selectedGiftAidStatus = '';
        this.selectedCompany = '';
        this.loadTransactions();
    }

    /**
     * Clear all selected rows tracked across pages.
     */
    clearSelection() {
        this.selectedMap.clear();
        this.selectedRowsIds = [];
    }

    /**
     * Reset filters, clear selection and reload transactions.
     */
    resetFilters() {
        this.startDate = null;
        this.endDate = null;
        this.selectedProduct = '';
        this.selectedGiftAidStatus = '';
        this.selectedCompany = '';
        this.clearSelection();
        this.loadTransactions();
    }

    /**
     * Handle selection/deselection of rows in the current page.
     * Params: event.detail.selectedRows - array of selected row objects.
     * Purpose: maintain selections across pages using selectedMap and update selectedRowsIds.
     */
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
    }

    /**
     * Navigate to the list view of Sales Invoice Transaction object.
     */
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

    /**
     * Handler for Close button.
     * Purpose: reset filters then navigate to list view.
     */
    handleClose() {
        this.resetFilters();
        setTimeout(() => {
            this.goToListView();
        }, 100);
    }

    /**
     * Submit selected transactions and then close (navigate away) if successful.
     * Purpose: call handleSubmit and on success reset and navigate.
     */
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

    /**
     * Submit selected transactions to Apex.
     * Returns: boolean indicating success.
     * Purpose: validate selection, call saveSubmission, refresh list and clear selection.
     */
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

    /**
     * Set data for current page based on pageNumber and pageSize.
     * Purpose: slice salesInvoiceTransactionData into singlePageSalesInvoiceTransactionData and sync selected IDs.
     */
    setPageData() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = this.pageNumber * this.pageSize;
        this.singlePageSalesInvoiceTransactionData = this.salesInvoiceTransactionData.slice(start, end);

        this.selectedRowsIds = Array.from(this.selectedMap.keys());
    }

    /**
     * Go to next page if available and update page data.
     */
    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.setPageData();
        }
    }

    /**
     * Go to previous page if available and update page data.
     */
    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.setPageData();
        }
    }

    /**
     * Getter: whether previous button should be disabled.
     */
    get isPrevDisabled() {
        return this.pageNumber <= 1;
    }

    /**
     * Getter: whether next button should be disabled.
     */
    get isNextDisabled() {
        return this.pageNumber >= this.totalPages;
    }

    /**
     * Getter: total number of selected rows across pages.
     */
    get totalSelected() {
        return this.selectedRowsIds.length;
    }

    /**
     * Utility: returns start of day ISO string for a date string.
     * Params: dateString - 'YYYY-MM-DD'
     */
    getStartOfDay(dateString) {
        let dt = new Date(dateString);
        dt.setHours(0, 0, 0, 0);
        return dt.toISOString();
    }

    /**
     * Utility: returns end of day ISO string for a date string.
     * Params: dateString - 'YYYY-MM-DD'
     */
    getEndOfDay(dateString) {
        let dt = new Date(dateString);
        dt.setHours(23, 59, 59, 999);
        return dt.toISOString();
    }

    /**
     * Dispatch a toast event.
     * Params: mTitle, mMessage, mVariant - used to show user notifications.
     */
    showToast(mTitle, mMessage, mVariant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: mTitle,
                message: mMessage,
                variant: mVariant
            }),
        )
    }

    /**
     * Export filtered transactions to Excel file
     * Purpose: Create an Excel file with all visible transaction data and download it
     */
    handleExportToExcel() {
        try {
            if (!this.salesInvoiceTransactionData || this.salesInvoiceTransactionData.length === 0) {
                this.showToast('Warning', 'No data available to export', 'warning');
                return;
            }

            const csvContent = this.generateCSVContent();
            const timestamp = new Date().toISOString().slice(0, 10);
            const filename = `Gift_Aid_Sales_Invoice_Transactions_${timestamp}.csv`;

            // IMPORTANT: data URI approach (Locker-safe)
            const csvData =
                'data:text/csv;charset=utf-8,\uFEFF' + encodeURIComponent(csvContent);

            const link = document.createElement('a');
            link.href = csvData;
            link.download = filename;
            link.style.display = 'none';

            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.showToast(
                'Success',
                `Exported ${this.salesInvoiceTransactionData.length} records`,
                'success'
            );

        } catch (error) {
            console.error('Export error:', error);
            this.showToast('Error', 'Failed to export data', 'error');
        }
    }

    /**
     * Generate CSV content from transaction data
     * Returns: String - CSV formatted data
     */
    generateCSVContent() {
        // Define headers
        const headers = [
            'Invoice Date',
            'Customer Reference',
            'Sales Header',
            'Company',
            'Account Name',
            'First Name',
            'Last Name',
            'Postal Code',
            'Product Name',
            'Nominal Code',
            'Sales VAT',
            'Paid Amount',
            'Analysis 1',
            'Analysis 2',
            'Analysis 6'
        ];

        // Create CSV header row
        let csv = headers.join(',') + '\r\n'; // Use \r\n for better Excel compatibility

        // Add data rows
        this.salesInvoiceTransactionData.forEach(record => {
            const row = [
                this.formatCSVField(record.invoiceDate),
                this.formatCSVField(record.customerReference),
                this.formatCSVField(record.salesInvoiceHeaderName),
                this.formatCSVField(record.companyName),
                this.formatCSVField(record.accountName),
                this.formatCSVField(record.contactFirstName),
                this.formatCSVField(record.contactLastName),
                this.formatCSVField(record.contactPostalCode),
                this.formatCSVField(record.productName),
                this.formatCSVField(record.nominalCode),
                this.formatCSVField(record.salesVAT),
                this.formatCSVField(record.paidAmount),
                this.formatCSVField(record.analysis1),
                this.formatCSVField(record.analysis2),
                this.formatCSVField(record.analysis6)
            ];
            csv += row.join(',') + '\r\n';
        });

        return csv;
    }

    /**
     * Format field value for CSV (handle special characters and null values)
     * Params: value - field value to format
     * Returns: String - properly escaped CSV field value
     */
    formatCSVField(value) {
        if (value === null || value === undefined || value === '') {
            return '';
        }

        // Convert to string
        let stringValue = String(value);

        // Escape double quotes by doubling them
        stringValue = stringValue.replace(/"/g, '""');

        // Wrap in quotes if contains comma, newline, or double quote
        if (stringValue.includes(',') || stringValue.includes('\r') || stringValue.includes('\n') || stringValue.includes('"')) {
            return `"${stringValue}"`;
        }

        return stringValue;
    }
}