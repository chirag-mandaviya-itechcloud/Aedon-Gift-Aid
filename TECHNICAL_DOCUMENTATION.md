# Gift Aid Submission System - Technical Documentation

**Project Name:** AEDON Gift Aid Submission System
**Version:** 1.0
**Last Updated:** January 2026
**Author:** Abhishek D
**Organization:** AEDON

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture](#system-architecture)
3. [Workflow Overview](#workflow-overview)
4. [Data Model & Objects](#data-model--objects)
5. [Component Details](#component-details)
   - 1.1 [LWC Component: giftAidSubmission](#1-lwc-component-giftaidsubmission)
   - 1.5 [Custom Buttons & Web Links](#15-custom-buttons--web-links-gift-aid-submission-access)
   - 2 [Apex Controller](#2-apex-controller-giftaidsubmissioncontroller)
6. [Key Logic & Business Rules](#key-logic--business-rules)
7. [Data Flow Diagram](#data-flow-diagram)
8. [Step-by-Step Process Flow](#step-by-step-process-flow)
9. [External Integrations](#external-integrations)
10. [Configuration & Settings](#configuration--settings)
11. [Dependencies](#dependencies)
12. [Error Handling & Recovery](#error-handling--recovery)
13. [Security Considerations](#security-considerations)
14. [Testing Strategy](#testing-strategy)

---

## Executive Summary

The **Gift Aid Submission System** is a Salesforce application that automates the submission of Gift Aid claims to HM Revenue & Customs (HMRC). The system:

- Enables users to select eligible Sales Invoice Transactions
- Builds compliant HMRC GovTalk XML payloads
- Submits to HMRC endpoints with digital signatures (IRmark)
- Polls HMRC for submission status updates
- Updates transaction records with final status (Accepted/Rejected)
- Handles encryption, OAuth, and secure communication with HMRC

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Gift Aid Submission System                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │  Custom Buttons      │  │   Custom Tab         │             │
│  │ (List View Access)   │─→│ Gift_Aid_Submission  │             │
│  │                      │  │                      │             │
│  │ • Sales_Invoice_Hdr  │  │  Opens LWC Component │             │
│  │ • Sales_Invoice_Trans│  │  in Tab Interface    │             │
│  └──────────────────────┘  └──────────┬───────────┘             │
│         ↑                              │                         │
│         │                              ↓                         │
│         │                   ┌──────────────────────┐             │
│         │                   │  LWC Component       │             │
│         │                   │  giftAidSubmission   │             │
│         └───────────────────│  • Filters & Search  │             │
│    Direct Link from         │  • Transaction List  │             │
│    Header/Transaction        │  • Multi-page Select│             │
│    Records                   │  • Submit to HMRC    │             │
│                              └──────────┬──────────┘             │
│                                         │                        │
│                                         ↓                        │
│                         ┌──────────────────────┐                │
│                         │  Apex Controller     │                │
│                         │ GiftAidSubmission    │                │
│                         │ Controller           │                │
│                         └──────────┬───────────┘                │
│                                    │                            │
│                                    ↓                            │
│                         ┌───────────────────┐                  │
│                         │ XML Payload Builder│                  │
│                         │  & IRmark Generator│                  │
│                         └───────────────────┘                  │
│                                    │                            │
│                                    ↓                            │
│                      ┌──────────────────────┐                  │
│                      │ HMRC Integration API │                  │
│                      │  (Submit & Encrypt)  │                  │
│                      └──────────────────────┘                  │
│                                    │                            │
│                                    ↓                            │
│                    ┌─────────────────────────────┐             │
│                    │ HMRC External Endpoints     │             │
│                    │ - submission_endpoint       │             │
│                    │ - polling_endpoint          │             │
│                    └─────────────────────────────┘             │
│                                    ↑                            │
│                                    │                            │
│         ┌──────────────────────────┴──────────────────────┐   │
│         │                                                  │   │
│         ↓                                                  │   │
│  ┌──────────────────┐                         ┌──────────┐│   │
│  │ Batch Job        │                         │ Scheduler││   │
│  │ GiftAidSubmission│                         │ GiftAid  ││   │
│  │ PollBatch        │                         │ Submission││  │
│  │ (Status Polling) │─ Scheduled by ──────────│ PollSchd ││   │
│  └──────────────────┘                         └──────────┘│   │
│         │                                                  │   │
│         ↓                                                  │   │
│    Update Gift_Aid_Submission__c & Sales_Invoice_Transaction__c
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Sales Force Database
├── Sales_Invoice_Header__c (with "Submit Gift Aid" button)
├── Sales_Invoice_Transaction__c (with "Submit Gift Aid" button)
├── Gift_Aid_Submission__c
├── Contact (with Gift Aid eligibility)
├── Company__c (Charity details)
└── Custom Metadata (Configuration)

User Access Points:
├─ Custom Button: Sales_Invoice_Header__c List View
├─ Custom Button: Sales_Invoice_Transaction__c List View
├─ Custom Tab: Gift_Aid_Submission__c (Salesforce Tab Bar)
└─ Direct Navigation: Tab reference or bookmark
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Lightning Web Component (LWC) | UI for transaction selection & filtering |
| **Backend** | Apex (Apex Classes) | Business logic, API calls, XML generation |
| **Database** | Salesforce Objects | Data storage & relationships |
| **Scheduling** | Apex Scheduler | Scheduled batch execution |
| **Batch Processing** | Apex Batch | Asynchronous status polling |
| **External Integration** | REST/HTTP Callouts | HMRC API communication |
| **Cryptography** | Apex Crypto API | AES encryption, SHA-1 hashing |
| **XML Processing** | Apex String & DOM manipulation | XML generation & parsing |

---

## Workflow Overview

### Main User Journey

```
User Access UI
    ↓
Set Filters (Date, Product, Company, Status)
    ↓
Load Eligible Transactions
    ↓
Select Transactions (Multi-page selection)
    ↓
Submit for HMRC
    ↓
Create Gift_Aid_Submission__c Record
    ↓
Update Transaction Status → "Submitted"
    ↓
Background Batch Job Monitors Status
    ↓
Receive HMRC Response (Acknowledgement → Response/Error)
    ↓
Update Final Status (Accepted or Rejected)
```

### Background Polling Workflow

```
Scheduler Triggered (Scheduled Frequency)
    ↓
Execute Batch Job
    ↓
Query Gift_Aid_Submission__c with Status != 'Success' & != 'Error'
    ↓
For Each Submission:
    • Call HMRC Polling API
    • Parse Response XML
    • Determine Status (Acknowledgement/Response/Error)
    • Update Gift_Aid_Submission__c Status
    • Update Related Sales_Invoice_Transaction__c Status
    • Optionally Call Delete API
    ↓
Complete Batch
```

---

## Data Model & Objects

### 1. Sales_Invoice_Transaction__c

Represents individual line items on sales invoices. Contains transaction details for Gift Aid eligibility.

**Key Fields:**
- `Id` (Primary Key): Unique identifier
- `Name`: Transaction name/number
- `Paid_Amount__c` (Currency): Amount eligible for Gift Aid
- `Gift_Aid_Submission_Status__c` (Picklist): Non-Submitted, Submitted, Accepted, Rejected
- `Gift_Aid_Submission__c` (Lookup): Reference to Gift_Aid_Submission__c
- `Sales_Invoice_Header__r` (Lookup): Parent invoice with account & date information
- `Product__r` (Lookup): Product reference (must have Gift_Aid_Eligible_Products__c = TRUE)
- `Company__c` (Lookup): Associated company
- Additional fields: Customer Reference, Nominal Code, Sales VAT, Analysis codes

**Status Lifecycle:**
```
Non-Submitted → Submitted → Accepted (✓ Success)
                                  ↓
                         Rejected (✗ Failed)
```

### 2. Gift_Aid_Submission__c

Records the submission of Gift Aid claims to HMRC.

**Key Fields:**
- `Id` (Primary Key): Unique identifier
- `Submission_Number__c` (Text): Unique HMRC Correlation ID (from HMRC response)
- `Submission_Date__c` (Date): Date of submission
- `Submitted_By__c` (Lookup to User): User who submitted
- `Gift_Aid_Polling_Status__c` (Picklist): In Progress, Success, Error
- `Polling_Error_Description__c` (Long Text): HMRC error details if rejected
- `Submission_Response__c` (Long Text Area): Initial HMRC XML response
- `Polling_Response__c` (Long Text Area): Latest polling response
- Relationship: `Sales_Invoice_Transactions__r` (one-to-many to Sales_Invoice_Transaction__c)

**Status Lifecycle:**
```
In Progress → Success (✓ Accepted by HMRC)
          ↓
        Error (✗ Rejected by HMRC)
```

### 3. Contact (Standard Object - Enhanced)

Represents individuals with Gift Aid eligibility markings.

**Key Fields:**
- `Id`: Contact identifier
- `FirstName` / `LastName`: Donor name
- `IsDonor__c` (Checkbox): Marked as donor
- `Eligible_for_Gift_Aid__c` (Checkbox): Gift Aid eligible
- `Gift_Aid_Declaration_Date__c` (Date): Start of eligibility
- `Gift_Aid_Expiry_Date__c` (Date): End of eligibility
- `Donor_Role__c` (Picklist): "Gift Aid Donor" required
- `MailingPostalCode` / `MailingStreet`: Address for HMRC submission
- `AccountId` (Lookup): Associated account (customer)

**Eligibility Requirements (ALL must be true):**
- `IsDonor__c` = TRUE
- `Eligible_for_Gift_Aid__c` = TRUE
- `Gift_Aid_Declaration_Date__c` < TODAY
- `Gift_Aid_Expiry_Date__c` > TODAY
- `Donor_Role__c` = 'Gift Aid Donor'

### 4. Company__c (Custom Object)

Represents the charity/organization submitting Gift Aid.

**Key Fields:**
- `Id`: Company identifier
- `Name`: Company/Charity name
- `Registered_Charity_Number__c` (Text): HMRC charity number
- `Company_PostalCode__c` (Text): Postal code
- `Telephone__c` (Phone): Contact number

### 5. Product2 (Standard Object - Enhanced)

Products/services eligible for Gift Aid.

**Key Fields:**
- `Id`: Product identifier
- `Name`: Product name
- `Gift_Aid_Eligible_Products__c` (Checkbox): Only TRUE products are eligible

---

## Component Details

### 1. LWC Component: `giftAidSubmission`

**File Location:** `force-app/main/default/lwc/giftAidSubmission/`

**Files:**
- `giftAidSubmission.js` (Controller logic)
- `giftAidSubmission.html` (Template)
- `giftAidSubmission.css` (Styling)
- `giftAidSubmission.js-meta.xml` (Configuration)

**Purpose:** Provides user interface for Gift Aid submission workflow

**Key Features:**

| Feature | Details |
|---------|---------|
| **Date Filtering** | Start Date & End Date inputs (filters by Invoice_Date__c) |
| **Product Filtering** | Dropdown with Gift Aid eligible products |
| **Status Filtering** | Dropdown to filter by Gift_Aid_Submission_Status__c |
| **Company Filtering** | Dropdown with current user's company as default |
| **Pagination** | 10 records per page with page navigation |
| **Multi-page Selection** | Selected row IDs persist across page changes using Map |
| **Data Table** | 16-column table showing transaction details |
| **Submission** | "Submit for Gift Aid" button to initiate submission |
| **Loading States** | Loading spinner during async operations |
| **Toast Notifications** | User feedback messages for success/error |

**Key Methods:**

```
connectedCallback()
├─ Load user's company
├─ Load transactions
├─ Load filter options
└─ Initialize component state

handleDateChange()
├─ Validate date range
├─ Call getTransactions()
└─ Reset pagination

handleComboboxChange()
├─ Update selected filter
└─ Call getTransactions()

handleSelectAllPages()
├─ Select all visible rows
└─ Add to selectedMap

handleSubmitClick()
├─ Validate selections
├─ Call saveSubmission()
└─ Navigate to record on success
```

**Data Binding:**
- `@track` properties for reactivity
- `selectedMap` (Map<String, Boolean>) for cross-page selection persistence
- `salesInvoiceTransactionData` for full result set
- `singlePageSalesInvoiceTransactionData` for paginated view

---

### 1.5. Custom Buttons & Web Links: Gift Aid Submission Access

**Purpose:** Provides quick access to the Gift Aid Submission LWC from Sales Invoice Header and Sales Invoice Transaction list views

#### Button 1: Sales_Invoice_Header__c - "Submit Gift Aid"

**Metadata File Location:** `force-app/main/default/weblinks/Sales_Invoice_Header__c.Gift_Aid_Submission.weblink-meta.xml`

**Button Configuration:**

| Property | Value |
|----------|-------|
| **Label** | Submit Gift Aid |
| **Name** | Gift_Aid_Submission |
| **Type** | CustomTab |
| **Display Location** | List View Button |
| **Availability** | All devices |
| **Target Tab** | Gift_Aid_Submission__c (custom tab) |
| **Icon** | Custom or Standard Icon |
| **Description** | Opens Gift Aid Submission interface for bulk selection and submission from invoices |

**How It Works:**
```
User on Sales_Invoice_Header__c List View
        ↓
Clicks "Submit Gift Aid" button
        ↓
System opens custom tab: "Gift_Aid_Submission__c"
        ↓
Loads giftAidSubmission LWC component
        ↓
LWC initializes with pre-filtered view
        (can be enhanced to filter by selected records)
        ↓
User can then:
├─ Adjust date/product/company filters
├─ Select transactions
└─ Submit for Gift Aid
```

**Behavior:**
- Button appears on all records in list view
- Click opens new/existing tab based on browser behavior
- Passes potential record context (if enhanced)
- Fully Responsive on desktop and mobile

---

#### Button 2: Sales_Invoice_Transaction__c - "Submit Gift Aid"

**Metadata File Location:** `force-app/main/default/weblinks/Sales_Invoice_Transaction__c.Gift_Aid_Submission.weblink-meta.xml`

**Button Configuration:**

| Property | Value |
|----------|-------|
| **Label** | Submit Gift Aid |
| **Name** | Gift_Aid_Submission |
| **Type** | CustomTab |
| **Display Location** | List View Button |
| **Availability** | All devices |
| **Target Tab** | Gift_Aid_Submission__c (custom tab) |
| **Icon** | Custom or Standard Icon |
| **Description** | Opens Gift Aid Submission interface for bulk selection and submission from transactions |

**How It Works:**
```
User on Sales_Invoice_Transaction__c List View
        ↓
Clicks "Submit Gift Aid" button (bulk or individual)
        ↓
System opens custom tab: "Gift_Aid_Submission__c"
        ↓
Loads giftAidSubmission LWC component
        ↓
LWC initializes with optional pre-filters
        (can be enhanced to pre-select clicked records)
        ↓
User can then:
├─ View pre-selected transactions
├─ Adjust filters
├─ Multi-select additional transactions
└─ Submit for Gift Aid
```

**Behavior:**
- Button appears on transaction list view
- Click opens custom tab (singleton - reuses existing tab)
- Can process individual or bulk selections
- Supports pre-population of record selections (future enhancement)

---

#### Custom Tab: "Gift_Aid_Submission__c"

**Metadata File Location:** `force-app/main/default/tabs/Gift_Aid_Submission__c.tab-meta.xml`

**Tab Configuration:**

| Property | Value |
|----------|-------|
| **Tab Label** | Gift Aid Submission |
| **Tab API Name** | Gift_Aid_Submission__c |
| **Tab Type** | Lightning Component Tab |
| **Component** | giftAidSubmission (LWC) |
| **Tab Icon** | Custom icon or standard gift icon |
| **Display Width** | Full width (fluid) |
| **Sidebar** | Visible or hidden (per user preference) |

**Tab Features:**
```
┌────────────────────────────────────────────────────────┐
│  Gift Aid Submission  [🔄] [×] [≡]                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌─ Search Filters ──────────────────────────────────┐ │
│  │                                                    │ │
│  │ Start Date: [____]  End Date: [____]              │ │
│  │ Product: [▼Select]  Status: [Non-Submitted ▼]    │ │
│  │ Company: [Current Company ▼]                     │ │
│  │                                                    │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  ┌─ Transactions Table ──────────────────────────────┐ │
│  │ ☐ Invoice Date | Cust Ref | Sales Header | ... │ │
│  │ ☐ 03/15/2025  | ORD-001  | INV-12345    | ... │ │
│  │ ☐ 03/14/2025  | ORD-002  | INV-12346    | ... │ │
│  │ ☐ 03/13/2025  | ORD-003  | INV-12347    | ... │ │
│  │                                                    │ │
│  │ Page 1 of 5                                       │ │
│  └────────────────────────────────────────────────────┘ │
│                                                        │
│  [Submit for Gift Aid]  [Clear Filters]              │ │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Tab Location:**
- Appears in main Salesforce tab bar
- Can be pinned/unpinned by users
- Multiple instances can be opened (browser default)
- Persists in user's recently used tabs

---

#### User Journey: Using Custom Buttons

**Scenario 1: From Sales Invoice Header List**
```
Step 1: User navigates to Reports → Sales Invoice Headers
Step 2: Views list of invoices with "Submit Gift Aid" button in toolbar
Step 3: Clicks "Submit Gift Aid" button
Step 4: New/Existing "Gift Aid Submission" tab opens
Step 5: giftAidSubmission LWC loads
Step 6: Filters display (default: current user's company)
Step 7: Transactions load automatically (all non-submitted)
Step 8: User can:
        ├─ Adjust date filters (optional)
        ├─ Filter by product (optional)
        ├─ Filter by status (optional)
        ├─ Select rows to submit
        └─ Click "Submit for Gift Aid"
```

**Scenario 2: From Sales Invoice Transaction List**
```
Step 1: User navigates to Reports → Sales Invoice Transactions
Step 2: Views list of transactions with "Submit Gift Aid" button
Step 3: User can:
        ├─ Select specific transactions via checkboxes
        ├─ Click "Submit Gift Aid" bulk button (or individual record's button)
        │
        OR
        │
        ├─ Click "Submit Gift Aid" on individual transaction record
Step 4: New/Existing "Gift Aid Submission" tab opens
Step 5: giftAidSubmission LWC loads
Step 6: (Optional Enhancement) Pre-selects clicked transaction(s)
Step 7: User can adjust selection & submit
```

**Scenario 3: Direct Tab Access**
```
Step 1: User can also directly click the "Gift Aid Submission" tab
        in main Salesforce tabs
Step 2: Opens component without any pre-filter
Step 3: User sets all filters manually
Step 4: Tab remembers state until closed
Step 5: Reopening tab resets to defaults
```

---

#### Technical Implementation Details

**Web Link XML Structure (Example):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<WebLink xmlns="http://soap.sforce.com/2006/04/metadata">
    <availability>online</availability>
    <description>Opens Gift Aid Submission interface</description>
    <displayType>link</displayType>
    <linkType>javascript</linkType>
    <masterLabel>Gift_Aid_Submission</masterLabel>
    <openType>newWindow</openType>
    <protected>false</protected>
    <url>javascript:
        // Option 1: Direct tab reference
        oneNavigationMenu.navigateToTab('Gift_Aid_Submission__c');

        // Option 2: With NavigationMixin (if enhanced)
        sforce.one.navigateToTab({
            identifier: 'Gift_Aid_Submission__c',
            params: {
                recordId: '{!Sales_Invoice_Header__c.Id}'
            }
        });
    </url>
</WebLink>
```

**Tab Navigation (Apex/LWC Enhancement):**
```apex
// Option 1: Standard Tab Navigation (JavaScript)
window.open(
    '/lightning/o/Gift_Aid_Submission__c/list',
    'Gift_Aid_Submission'
);

// Option 2: Using NavigationMixin (from LWC)
import { NavigationMixin } from 'lightning/navigation';

@wire(MessageContext)
messageContext;

navigateToTab() {
    this[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: 'Gift_Aid_Submission__c'
        }
    });
}
```

---

#### Enhancement Opportunities

**Future Enhancements:**
1. Pre-populate selected records from origin list
   - Pass record IDs to LWC via URL parameter
   - Auto-check those records in the table

2. Filter transactions by selected header
   - When opened from Header record, show only its transactions
   - Reduce user selection time for related records

3. Context-aware filtering
   - Remember last used filters per user
   - Save filter combinations as quick views

4. Bulk action confirmation
   - Show summary of selected records before submission
   - Allow final review of donor data

5. Direct submission status view
   - Add status column on origin lists
   - Link to submission records from list button

---

### 2. Apex Controller: `GiftAidSubmissionController`

**File Location:** `force-app/main/default/classes/GiftAidSubmissionController.cls`

**Purpose:** Handles all backend operations for Gift Aid submission

#### Method: `getTransactions()`

**Signature:**
```apex
@AuraEnabled
public static List<GiftAidSubmissionResultWrapper> getTransactions(
    Date startDate,
    Date endDate,
    String productId,
    String giftAidStatus,
    String companyId
)
```

**Steps:**
1. **Query Eligible Contacts:**
   - Fetch all Contacts where:
     - `IsDonor__c = TRUE`
     - `Eligible_for_Gift_Aid__c = TRUE`
     - `Gift_Aid_Declaration_Date__c < TODAY`
     - `Gift_Aid_Expiry_Date__c > TODAY`
     - `Donor_Role__c = 'Gift Aid Donor'`
   - Create Map: Account ID → Contact

2. **Build Dynamic Query:**
   - Base query: `Sales_Invoice_Transaction__c` with Gift Aid eligible products
   - Apply optional filters:
     - Start Date: `Invoice_Date__c >= :startDate`
     - End Date: `Invoice_Date__c <= :endDate`
     - Product ID: `Product__r.Id = :productId`
     - Gift Aid Status: `Gift_Aid_Submission_Status__c = :giftAidStatus`
     - Company: `Company__c = :companyId`
   - Order by: `Invoice_Date__c DESC`

3. **Build Wrapper Objects:**
   - For each transaction, retrieve:
     - Transaction details (ID, Name, Amount)
     - Header details (Invoice Date, Header Name)
     - Account details (Account Name)
     - Company details (Company Name)
     - Product details (Product Name, Nominal Code)
     - Related contact info (First Name, Last Name, Postal Code)
   - Validate contact exists in Map before populating

4. **Return:**
   - `List<GiftAidSubmissionResultWrapper>` with all 18 fields populated

---

#### Method: `saveSubmission()`

**Signature:**
```apex
@AuraEnabled
public static String saveSubmission(List<Id> salesTransactionIds)
```

**Steps:**

**Step 1: Fetch Transaction Data**
```
Query Sales_Invoice_Transaction__c by Ids
Retrieve:
  - Transaction ID, Name, Amount
  - Gift_Aid_Submission_Status__c
  - CreatedDate
  - Sales_Invoice_Header__r.Account__r.Id (for donor lookup)
```

**Step 2: Gather Configuration**
```
Get GiftAidSubmission__c custom setting:
  - senderId → HMRC sender ID
  - charityId → Registered charity ID
  - pass → Authentication password
  - Channel_URI, Channel_Product, Channel_Version
  - endpoint → HMRC submission endpoint
  - polling_endpoint → HMRC polling endpoint

Get Company__c details:
  - Name → Company/Charity name
  - Registered_Charity_Number__c
  - Company_PostalCode__c
  - Telephone__c
```

**Step 3: Map Donor Contacts**
```
From transaction Account IDs:
  Query Contact records where:
    - AccountId IN :selectedDonorAccIds
    - IsDonor__c = TRUE
    - Eligible_for_Gift_Aid__c = TRUE
    - Gift_Aid_Declaration_Date__c < TODAY
    - Gift_Aid_Expiry_Date__c > TODAY

Create Map: Account ID → Contact
  (contains FirstName, LastName, MailingPostalCode, MailingStreet)
```

**Step 4: Build XML Payload**
```
Call buildXmlPayloadString() with:
  - Transactions list
  - Configuration data
  - Account → Contact mapping

Generates GovTalk XML structure:
  ├─ Message Header
  │  ├─ Class: HMRC-CHAR-CLM
  │  ├─ SenderID & Authentication
  │  └─ CorrelationID (empty - to be filled by HMRC)
  ├─ GovTalk Details
  │  ├─ Charity ID (Key)
  │  └─ Channel routing
  └─ Body (R68 form)
     ├─ Auth Official Details
     ├─ Organization Details
     └─ GAD Entries (one per transaction)
        ├─ Donor Name & Address
        ├─ Transaction Date
        └─ Transaction Amount
```

**Step 5: Generate Digital Signature (IRmark)**
```
Call HMRCIRmarkGenerator.processCharitySubmission():
  - Extracts Body content
  - Canonicalizes XML per W3C C14N spec
  - Generates SHA-1 hash
  - Encodes to base-64 and base-32
  - Replaces IRmark placeholder in XML

Returns: Signed XML payload
```

**Step 6: Submit to HMRC**
```
Call callHMRC():
  - Setting: POST request
  - Content-Type: text/xml
  - Body: Signed XML payload
  - Target: Submission endpoint (custom setting)

Returns: XML response containing:
  - CorrelationID (Submission Number)
  - Acknowledgement/Response qualifier
  - Error details (if applicable)
```

**Step 7: Create Gift_Aid_Submission__c**
```
New Gift_Aid_Submission__c record:
  - Submission_Number__c = extracted CorrelationID
  - Submission_Date__c = TODAY
  - Submitted_By__c = UserInfo.getUserId()
  - Submission_Response__c = Full response XML
  - Gift_Aid_Polling_Status__c = 'In Progress'

Insert record → Returns new record ID
```

**Step 8: Update Sales Transactions**
```
For each transaction in scope:
  - Gift_Aid_Submission_Status__c = 'Submitted'
  - Gift_Aid_Submission__c = New Gift_Aid_Submission__c Id

Update all records in batch
```

**Step 9: Return Success**
```
Return 'Success' string
```

**Error Handling:**
- Any exception wrapped in AuraHandledException
- Message propagated to LWC for display

---

#### Method: `buildXmlPayloadString()`

**Signature:**
```apex
private static String buildXmlPayloadString(
    List<Sales_Invoice_Transaction__c> txns,
    Map<String,String> configData,
    Map<Id, Contact> accToConMap
)
```

**XML Structure Generated:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">
  <EnvelopeVersion>2.0</EnvelopeVersion>
  <Header>
    <MessageDetails>
      <Class>HMRC-CHAR-CLM</Class>
      <Qualifier>request</Qualifier>
      <Function>submit</Function>
      <CorrelationID/> <!-- Empty, filled by HMRC -->
      <Transformation>XML</Transformation>
      <GatewayTest>1</GatewayTest>
    </MessageDetails>
    <SenderDetails>
      <IDAuthentication>
        <SenderID>{senderId}</SenderID>
        <Authentication>
          <Method>clear</Method>
          <Role>principal</Role>
          <Value>{password}</Value>
        </Authentication>
      </IDAuthentication>
    </SenderDetails>
  </Header>
  <GovTalkDetails>
    <Keys>
      <Key Type="CHARID">{charityId}</Key>
    </Keys>
    <TargetDetails>
      <Organisation>HMRC</Organisation>
    </TargetDetails>
    <ChannelRouting>
      <Channel>
        <URI>{Channel_URI}</URI>
        <Product>{Channel_Product}</Product>
        <Version>{Channel_Version}</Version>
      </Channel>
    </ChannelRouting>
  </GovTalkDetails>
  <Body>
    <IRenvelope xmlns="http://www.govtalk.gov.uk/taxation/charities/r68/2">
      <IRheader>
        <Keys>
          <Key Type="CHARID">{charityId}</Key>
        </Keys>
        <PeriodEnd>{60 days from today}</PeriodEnd>
        <DefaultCurrency>GBP</DefaultCurrency>
        <IRmark Type="generic">PlaceHolder</IRmark>
        <Sender>Individual</Sender>
      </IRheader>
      <R68>
        <AuthOfficial>
          <OffName>
            <Fore>{Company Name}</Fore>
            <Sur>{Company Name}</Sur>
          </OffName>
          <OffID>
            <Postcode>{Postal Code}</Postcode>
          </OffID>
          <Phone>{Telephone}</Phone>
        </AuthOfficial>
        <Declaration>yes</Declaration>
        <Claim>
          <OrgName>{Company Name}</OrgName>
          <HMRCref>{charityId}</HMRCref>
          <Regulator>
            <RegName>{Company Name}</RegName>
            <RegNo>{Registered Charity Number}</RegNo>
          </Regulator>
          <Repayment>
            <!-- Multiple GAD entries -->
            <GAD>
              <Donor>
                <Fore>{Contact FirstName}</Fore>
                <Sur>{Contact LastName}</Sur>
                <House>{Contact Street Address}</House>
                <Postcode>{Contact Postal Code}</Postcode>
              </Donor>
              <Date>{Transaction CreatedDate}</Date>
              <Total>{Transaction Paid Amount}</Total>
            </GAD>
            <!-- ... more GAD entries ... -->
            <EarliestGAdate>{Earliest Transaction Date}</EarliestGAdate>
          </Repayment>
        </Claim>
      </R68>
    </IRenvelope>
  </Body>
</GovTalkMessage>
```

**Key Points:**
- One `<GAD>` (Gift Aid Declaration) entry per transaction
- IRmark placeholder to be replaced by IRmark generator
- Earliest GA date calculated across all transactions

---

#### Helper Methods

**`parseXmlTag(String xml, String tagName)`**
- Extracts simple XML tag values using string indexing
- Not a full XML parser (suitable for known response structure)
- Returns null if tag not found

**`callHMRC(String xmlPayload, String endpoint)`**
- Makes HTTP POST request to HMRC endpoint
- Sets Content-Type: text/xml
- Returns response body as String

**`getCurrentUserCompany()`**
- Retrieves current user's assigned company
- Queries User.aednpc__Current_Logged_In_Company__c
- Returns Map with companyId and companyName

**`getProductFilterOptions()`**
- Returns List of Gift Aid eligible products
- Filters on `Gift_Aid_Eligible_Products__c = TRUE`

**`getGiftAidStatusOptions()`**
- Returns picklist values from Sales_Invoice_Transaction__c.Gift_Aid_Submission_Status__c
- Returns List<Map<String, String>> with label/value pairs

**`getCompanyFilterOptions()`**
- Returns all Company records ordered by Name

---

### 3. Apex Batch Job: `GiftAidSubmissionPollBatch`

**File Location:** `force-app/main/default/classes/GiftAidSubmissionPollBatch.cls`

**Purpose:** Asynchronously polls HMRC for submission status updates

**Method: `start(Database.BatchableContext BC)`**

**Returns:** `Database.QueryLocator`

**Query:**
```apex
SELECT Id, Submission_Number__c, Polling_Response__c, Gift_Aid_Polling_Status__c,
       Polling_Error_Description__c,
       (SELECT Id, Gift_Aid_Submission_Status__c FROM Sales_Invoice_Transactions__r)
FROM Gift_Aid_Submission__c
WHERE Gift_Aid_Polling_Status__c != 'Success'
  AND Gift_Aid_Polling_Status__c != 'Error'
```

**Selects:** Gift_Aid_Submission records in 'In Progress' state, plus related transactions

---

**Method: `execute(Database.BatchableContext BC, List<SObject> scope)`**

**Batch Size Recommendation:** 50 records per batch

**Steps for Each Submission:**

**Step 1: Retrieve Configuration**
```
Get GiftAidSubmission__c custom settings:
  - endpoint → For delete API calls
  - polling_endpoint → For polling API calls
```

**Step 2: Call Polling API**
```
For each Gift_Aid_Submission__c:
  - Submission_Number = submission.Submission_Number__c
  - Call callPollingAPI(Submission_Number, pollingEndpoint)
  - Returns XML response
  - Store in submission.Polling_Response__c
```

**Step 3: Parse Polling Response**
```
Extract XML tags from response:
  - CorrelationID → Must match Submission_Number
  - Qualifier → Can be 'error', 'response', or 'acknowledgement'
  - Function → Must be 'submit'
```

**Step 4: Evaluate Response & Update Status**

**Case 1: Error Response (Qualifier = 'error')**
```
- Extract error details:
  - RaisedBy (Who raised the error)
  - Number (Error code)
  - Type (Error type)
  - Text (Error message)

- Create error description: "{RaisedBy} - {Number} - {Type} - {Text}"

- Set submission fields:
  - Polling_Error_Description__c = error_description
  - Gift_Aid_Polling_Status__c = 'Error'

- Call callDeleteAPI() to remove from HMRC

- Update all related Sales_Invoice_Transaction__c:
  - Gift_Aid_Submission_Status__c = 'Rejected'
```

**Case 2: Success Response (Qualifier = 'response')**
```
- No error details to extract

- Set submission fields:
  - Polling_Error_Description__c = '' (empty)
  - Gift_Aid_Polling_Status__c = 'Success'

- Call callDeleteAPI() to remove from HMRC (cleanup)

- Update all related Sales_Invoice_Transaction__c:
  - Gift_Aid_Submission_Status__c = 'Accepted'
```

**Case 3: In Progress (Qualifier = 'acknowledgement')**
```
- No action needed on error or transactions

- Set submission field:
  - Gift_Aid_Polling_Status__c = 'In Progress'

- Will be polled again next batch cycle
```

**Step 5: Verify Correlation ID**
```
If CorrelationID doesn't match Submission_Number:
  - Skip processing
  - Don't update records
  - Log warning (optional)
```

**Step 6: Bulk Update**
```
Update all modified Gift_Aid_Submission__c records
Update all modified Sales_Invoice_Transaction__c records
```

---

**Method: `callPollingAPI(String submissionNumber, String endpoint)`**

**Polling XML Request:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">
  <EnvelopeVersion>2.0</EnvelopeVersion>
  <Header>
    <MessageDetails>
      <Class>HMRC-CHAR-CLM</Class>
      <Qualifier>poll</Qualifier>
      <Function>submit</Function>
      <CorrelationID>{submissionNumber}</CorrelationID>
      <Transformation>XML</Transformation>
    </MessageDetails>
  </Header>
  <GovTalkDetails>
    <Keys/>
  </GovTalkDetails>
</GovTalkMessage>
```

**Execution:**
- HTTP POST to polling endpoint
- Content-Type: text/xml
- Returns response body

---

**Method: `callDeleteAPI(String submissionNumber, String endpoint)`**

**Delete XML Request:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">
  <EnvelopeVersion>2.0</EnvelopeVersion>
  <Header>
    <MessageDetails>
      <Class>HMRC-CHAR-CLM</Class>
      <Qualifier>request</Qualifier>
      <Function>delete</Function>
      <CorrelationID>{submissionNumber}</CorrelationID>
      <Transformation>XML</Transformation>
    </MessageDetails>
  </Header>
  <GovTalkDetails>
    <Keys/>
  </GovTalkDetails>
</GovTalkMessage>
```

**Execution:**
- HTTP POST to submission/delete endpoint
- Removes previously submitted message from HMRC queue

---

**Method: `parseXmlTag(String xml, String tagName)`**
- Helper to extract tag values from response XML
- Returns string value or null

---

**Method: `finish(Database.BatchableContext BC)`**
- Called when batch completes
- Currently logs completion message
- Can be extended for post-processing or notifications

---

### 4. Apex Scheduler: `GiftAidSubmissionPollScheduler`

**File Location:** `force-app/main/default/classes/GiftAidSubmissionPollScheduler.cls`

**Purpose:** Triggers the polling batch at scheduled intervals

**Method: `execute(SchedulableContext SC)`**

**Implementation:**
```apex
Database.executeBatch(new GiftAidSubmissionPollBatch(), 50);
```

**Configuration:**
- Batch Size: 50 records per batch
- Called by Salesforce scheduler

**Usage:**
```
Schedule using System > Apex Classes > Schedule Apex
Example: "0 0 12 * * ?" (runs daily at noon)
```

---

### 5. HMRC Integration: `HMRCIntegrationAPI`

**File Location:** `force-app/main/default/classes/HMRCIntegrationAPI.cls`

**Purpose:** Handles OAuth, encryption, decryption for HMRC integration

**Key Methods:**

#### Encryption/Decryption

**`EncryptRecordData(String data)`**
- Algorithm: AES128
- Includes User ID prefix for security
- Returns Base64-encoded encrypted data

**`DecryptRecordData(String encryptedData)`**
- Algorithm: AES128
- Validates User ID prefix
- Returns original data

**`EncryptSessionToken(String data)` / `DecryptSessionToken(String data)`**
- Session token encryption with User ID verification
- Throws AuraHandledException if User ID mismatch

**`DecryptStateInformation(String encryptedState)`**
- Algorithm: AES256
- Uses double-key (Privatekey + Privatekey)
- Hex-encoded input

---

#### OAuth Authorization

**`authorizationAPI(String companyId)`**

**Generates:** Authorization URL for HMRC OAuth flow

**Components:**
- Client ID from metadata
- Scope from metadata
- Encodes company ID and app URL as state (encrypted)
- Returns encoded state in URL

**Response:** Authorization URL to redirect user to HMRC login

---

**`getAccessTokenFromCode(String accessCode, String encryptedCompanyId)`**

**Steps:**
1. Get HMRC token endpoint and client secret from metadata
2. Build token request body with:
   - Client ID & Secret
   - Grant type: "authorization_code"
   - Authorization code (from OAuth redirect)
   - Redirect URI
3. POST to token endpoint
4. Parse and store access token for future API calls

---

### 6. IRmark Generator: `HMRCIRmarkGenerator`

**File Location:** `force-app/main/default/classes/HMRCIRmarkGenerator.cls`

**Purpose:** Generates digital signature (IRmark) for HMRC compliance

**Method: `generateIRmark(String xmlBody)`**

**Signature Process:**

**Step 1: Extract Namespace**
```
Parse GovTalkMessage element for xmlns attribute
Extract: "http://www.govtalk.gov.uk/CM/envelope"
```

**Step 2: Extract Body Content**
```
Find <Body>...</Body> tags
Extract everything between (including tags)
```

**Step 3: Add Namespace to Body**
```
Modify: <Body> → <Body xmlns="...">
Ensures proper namespace prefix for canonicalization
```

**Step 4: Remove IRmark Element**
```
Regex: Remove <IRmark[^>]*>.*?</IRmark>
Clears placeholder before hashing
```

**Step 5: Canonicalize XML**
```
W3C C14N Canonicalization Rules:
  1. Remove XML declaration (<?xml ... ?>)
  2. Normalize line endings (CRLF → LF)
  3. Remove comments
  4. Trim leading/trailing whitespace
  5. Preserve internal whitespace per HMRC spec

Result: Deterministic XML representation for hashing
```

**Step 6: Generate SHA-1 Hash**
```
Apply SHA-1 to canonical XML UTF-8 bytes
Produces 20-byte hash
```

**Step 7: Encode Hash**
```
Base64 Encoding:
  - Standard Base64 alphabet
  - Used for IRmark in submission

Base32 Encoding:
  - RFC 4648 alphabet (A-Z, 2-7)
  - Human-readable format
```

**Returns:**
```
Map with keys:
  - 'base64': Base64-encoded hash (used in XML)
  - 'base32': Base32-encoded hash (human-readable)
  - 'canonical': Canonical XML for debugging
```

---

**Method: `processCharitySubmission(String xmlPayload)`**

**Integration Point:**
1. Receives unsigned XML from Controller
2. Generates IRmark by calling generateIRmark()
3. Replaces "PlaceHolder" in IRmark element with base64 value
4. Returns signed XML ready for HMRC submission

---

---

## Key Logic & Business Rules

### Eligibility Rules

#### Transaction Eligibility
✓ Eligible if:
- Product has `Gift_Aid_Eligible_Products__c = TRUE`
- Company matches current user's company (optional filter)
- Gift_Aid_Submission_Status__c in ['Non-Submitted', 'Rejected']
- Sales_Invoice_Header.Invoice_Date between filter dates (optional)

#### Donor Eligibility
✓ Eligible if ALL conditions met:
- Contact has `IsDonor__c = TRUE`
- Contact has `Eligible_for_Gift_Aid__c = TRUE`
- Contact's `Gift_Aid_Declaration_Date__c < TODAY`
- Contact's `Gift_Aid_Expiry_Date__c > TODAY`
- Contact's `Donor_Role__c = 'Gift Aid Donor'`
- Belongs to Account that is transaction's payer

#### Company Eligibility
- Must be registered with HMRC (has Registered_Charity_Number__c)
- Must have valid contact details (Postal Code, Phone)

---

### Status Transition Rules

**Sales_Invoice_Transaction__c Status Flows:**

```
Non-Submitted
    ↓
    └──→ Select & Submit ──→ Submitted
                                ↓
                         ┌───────┴───────┐
                         ↓               ↓
                      Accepted        Rejected
                      (Final)         (Final)

Rejected
    ↓
    └──→ Resubmit ──→ Submitted (again)
            ↓
         Same flow
```

**Gift_Aid_Submission__c Status Flows:**

```
In Progress
    ↓
    ├─→ Polling receives ERROR response ──→ Error (Final)
    │
    └─→ Polling receives SUCCESS response ──→ Success (Final)
        (but transactions may be individually Accepted/Rejected by HMRC)
```

---

### Validation Rules

| Validation | Scope | Rule |
|-----------|-------|------|
| Donor Exists | saveSubmission | Every transaction must have eligible donor contact |
| Contact Postal Code | saveSubmission | Contact must have MailingPostalCode |
| Contact Name | saveSubmission | Contact must have FirstName AND LastName |
| Company Details | saveSubmission | Company must have Postal Code & Phone |
| Payload Not Empty | saveSubmission | At least 1 eligible transaction must be selected |
| Correlation ID Match | execute (batch) | Polling response CorrelationID must match Submission_Number |

---

## Data Flow Diagram

### User Submission Flow

```
STEP 0: USER INITIATES ACCESS VIA BUTTON
┌─────────────────────────────────────────────┐
│  User on Sales Invoice Header OR            │
│  Sales Invoice Transaction List View        │
└──────────────┬──────────────────────────────┘
               │
               ├─────────────────────────────────────────┐
               ↓                                         │
    ┌────────────────────────────────┐                 │
    │ Locate "Submit Gift Aid"       │      OR         │
    │ Button in List Toolbar         │←────────────────┤
    └────────────┬───────────────────┘                 │
                 │                                       │
                 ↓               ┌──────────────────────┘
        ┌────────────────────────────────────┐
        │ Click "Submit Gift Aid" Button     │
        │ (Custom WebLink)                   │
        └────────────┬───────────────────────┘
                     │
                     ↓
        ┌────────────────────────────────────┐
        │ System Navigates to Custom Tab:    │
        │ "Gift_Aid_Submission__c"           │
        │ ├─ Component: giftAidSubmission    │
        │ ├─ Opens in Salesforce Tab Bar    │
        │ └─ Full-width responsive view     │
        └────────────┬───────────────────────┘
                     │
         ┌───────────┴─────────────┐
         │                         │
         ↓                         ↓
    ┌─────────────┐           ┌─────────────┐
    │ Tab Already │           │ Tab Not     │
    │ Open        │           │ Open Yet    │
    │ → Reuse     │           │ → Create    │
    │   existing  │           │   new tab   │
    │   tab       │           │   instance  │
    └────┬────────┘           └────┬────────┘
         └────────────┬─────────────┘
                      │
                      ↓
STEP 1: LWC COMPONENT LOADS IN TAB
┌──────────────────────────────────────┐
│  giftAidSubmission LWC Loads         │
│  ├─ connectedCallback() triggered    │
│  └─ Component initializes            │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Load Configuration & Filter Options  │
│  ├─ Load user's company               │
│  ├─ Load Gift Aid eligible products   │
│  ├─ Load submission status options    │
│  └─ Load all companies                │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ getTransactions() Called             │
│ ├─ Filter by date range (optional)   │
│ ├─ Filter by product (optional)      │
│ ├─ Filter by status (default:        │
│ │  Non-Submitted)                    │
│ └─ Filter by company (user's company)│
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────────┐
│ APEX CONTROLLER: getTransactions()       │
│ 1. Query eligible contacts               │
│ 2. Build dynamic query for transactions  │
│ 3. Join with related data                │
│ 4. Return GiftAidSubmissionResultWrapper │
└──────────────┬──────────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Query Sales_Invoice_Transaction__c  │
│ WHERE:                              │
│ - Product.Gift_Aid_Eligible = TRUE  │
│ - Contact is Gift Aid eligible      │
│ - Status = 'Non-Submitted' (or user │
│   selected status)                  │
└──────────────┬──────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Fetch Related Contact Data            │
│ ├─ FirstName, LastName               │
│ ├─ MailingPostalCode                 │
│ └─ MailingStreet                     │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Return GiftAidSubmissionResult        │
│ Wrapper Objects to LWC               │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ LWC Renders Data Table               │
│ ├─ Pagination: 10 records per page   │
│ ├─ Multiple columns with data        │
│ ├─ Row selection checkboxes          │
│ └─ Ready for user interaction        │
└──────────────┬───────────────────────┘
               │

STEP 2-6: CONTINUE WITH USER INTERACTION...
               │
               ↓
┌──────────────────────────────────────┐
│ User Adjusts Filters (Optional)      │
│ & Selects Transactions               │
│ (See Steps 2-3 for details)          │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ User Clicks Submit Button            │
│ (See Step 4 for details)             │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ saveSubmission(List<Id>) Called      │
│ WITH selected transaction IDs        │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Query Full Transaction Data          │
│ + Related Header/Account/Company     │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ Query Eligible Contacts              │
│ Create Account → Contact mapping     │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ buildXmlPayloadString()              │
│ ├─ Add transaction headers           │
│ ├─ Add charity details               │
│ └─ Add one GAD entry per transaction │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ HMRCIRmarkGenerator.                 │
│ processCharitySubmission()           │
│ ├─ Canonicalize body                 │
│ ├─ Generate SHA-1 hash               │
│ ├─ Encode to Base64 & Base32         │
│ └─ Insert IRmark into XML            │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ callHMRC()                           │
│ POST signed XML to HMRC endpoint     │
│ Content-Type: text/xml               │
└──────────────┬───────────────────────┘
               │
               ↓
           [HMRC Gateway]
               │
               ↓
┌──────────────────────────────────────┐
│ HMRC Response XML                    │
│ Contains:                            │
│ - CorrelationID (Submission Number)  │
│ - Qualifier: 'acknowledgement'       │
└──────────────┬───────────────────────┘
               │
               ↓
┌──────────────────────────────────────┐
│ parseXmlTag() Extract Values         │
│ - CorrelationID → Submission Number  │
└──────────┬───────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ CREATE Gift_Aid_Submission__c        │
│ ├─ Submission_Number__c = ID         │
│ ├─ Submission_Date__c = TODAY        │
│ ├─ Submitted_By__c = User ID         │
│ ├─ Submission_Response__c = XML      │
│ └─ Gift_Aid_Polling_Status__c        │
│    = 'In Progress'                   │
└──────────┬───────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ UPDATE Sales_Invoice_Transaction__c  │
│ FOR each selected transaction:       │
│ ├─ Gift_Aid_Submission_Status__c     │
│    = 'Submitted'                     │
│ └─ Gift_Aid_Submission__c = New ID   │
└──────────┬───────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ Return 'Success' to LWC              │
│ Navigate to Gift_Aid_Submission__c   │
│ record                               │
└──────────────────────────────────────┘
```

---

### Polling Flow

```
┌────────────────────────────────────────┐
│ Scheduler Triggered at Set Time        │
│ (e.g., every 30 minutes, hourly, etc) │
└────────────┬─────────────────────────┘
             │
             ↓
┌────────────────────────────────────────┐
│ Database.executeBatch()                │
│ GiftAidSubmissionPollBatch (batch 50)  │
└────────────┬─────────────────────────┘
             │
             ↓
┌────────────────────────────────────────┐
│ start() method                         │
│ Query Gift_Aid_Submission__c WHERE:    │
│ - Status != 'Success'                  │
│ - Status != 'Error'                    │
│ (Only 'In Progress' records)           │
└────────────┬─────────────────────────┘
             │
             ↓
┌────────────────────────────────────────┐
│ execute() for each batch of 50 records │
│                                        │
└────────┬───────────────────────────────┘
         │
         ├──→ For each submission:
         │
         ├──1. callPollingAPI()
         │    POST polling request with
         │    Submission_Number to HMRC
         │
         ├──2. Store response in
         │    Polling_Response__c
         │
         ├──3. Parse response XML
         │    Extract:
         │    - CorrelationID
         │    - Qualifier (error/response/acknowledgement)
         │    - Error details (if applicable)
         │
         ├──4. Match CorrelationID
         │    Verify it equals Submission_Number
         │
         ├──5. Evaluate Status
         │
         ├─────────────┬──────────────┬────────────┐
         │             │              │            │
         ↓             ↓              ↓            ↓
      [ERROR]      [SUCCESS]    [ACKNOWLEDGEMENT]
         │             │              │
         ├─────────────┴──────────────┘
         │
         ├──6. If ERROR or SUCCESS:
         │    • Update Gift_Aid_Submission__c
         │    │ ├─ Status = ERROR/SUCCESS
         │    │ └─ Error_Desc (if error)
         │    •
         │    • callDeleteAPI() cleanup
         │    •
         │    • Update all related
         │      Sales_Invoice_Transaction__c
         │      └─ Status = REJECTED/ACCEPTED
         │
         ├──7. If ACKNOWLEDGEMENT:
         │    • Keep Status = In Progress
         │    • Will poll again next cycle
         │
         └──8. Bulk Update Records
              (gift_aid_submissions,
               sales_invoice_transactions)
             │
             ↓
┌────────────────────────────────────────┐
│ finish() method                        │
│ Log completion (optional)              │
└────────────────────────────────────────┘
```

---

## Step-by-Step Process Flow

### Complete End-to-End User Journey

---

#### **Step 0: User Initiates Access via Custom Button (List View Entry Point)**

**What Happens:**
1. User navigates to Sales Invoice Header or Sales Invoice Transaction list view
2. User locates the "Submit Gift Aid" button in the list view toolbar
3. User clicks the button
4. System opens/activates the custom tab with the LWC component

**Scenario A: From Sales_Invoice_Header__c List View**
```
User Action Flow:
├─ Navigate to Reports → Sales Invoice Headers (List View)
├─ Or: Navigate to Sales_Invoice_Header__c Tab → List All Records
|
├─ View list of invoices displayed in table format
├─ Locate "Submit Gift Aid" button in list view toolbar/actions
│  (Button appears for users with appropriate permissions)
│
├─ Click "Submit Gift Aid" button
│  └─ Onclick Event Triggered
│     ├─ Button Type: Custom Web Link (WebLink)
│     ├─ Target: Custom Tab "Gift_Aid_Submission__c"
│     ├─ Navigation Type: Open Tab Reference
│     └─ Action: navigateToTab({identifier: 'Gift_Aid_Submission__c'})
│
├─ Salesforce Tab System Processes:
│  ├─ Check if tab already open → Reuse existing tab
│  ├─ Check if tab never opened → Create new tab
│  └─ Activate tab (bring to focus)
│
└─ Custom Tab Opens with LWC Component
   └─ giftAidSubmission LWC loads
      └─ Component renders in full-width tab view
```

**Scenario B: From Sales_Invoice_Transaction__c List View**
```
User Action Flow:
├─ Navigate to Reports → Sales Invoice Transactions (List View)
├─ Or: Navigate to Sales_Invoice_Transaction__c Tab → List All Records
│
├─ View list of transactions displayed in table format
├─ Locate "Submit Gift Aid" button in list view toolbar/actions
│  (Button appears for users with appropriate permissions)
│
├─ Click Single Record's "Submit Gift Aid" Button
│  OR Select Multiple Records + Click Bulk "Submit Gift Aid" Button
│  └─ Onclick Event Triggered
│     ├─ Button Type: Custom Web Link (WebLink)
│     ├─ Target: Custom Tab "Gift_Aid_Submission__c"
│     ├─ Navigation Type: Open Tab Reference
│     └─ Action: navigateToTab({identifier: 'Gift_Aid_Submission__c'})
│
├─ Salesforce Tab System Processes:
│  ├─ Check if tab already open → Reuse existing tab
│  ├─ Check if tab never opened → Create new tab
│  └─ Activate tab (bring to focus)
│
└─ Custom Tab Opens with LWC Component
   └─ giftAidSubmission LWC loads
      └─ Component renders in full-width tab view
```

**Custom Tab Details:**

| Aspect | Details |
|--------|---------|
| **Tab Name** | Gift_Aid_Submission__c |
| **Tab Label** | Gift Aid Submission |
| **Tab Type** | Lightning Web Component Tab |
| **Component** | giftAidSubmission (LWC) |
| **Tab Icon** | Gift/Donation icon (customizable) |
| **Display Mode** | Full width, responsive |
| **Sidebar** | Visible by default (user can toggle) |
| **Tab Behavior** | Singleton - one tab instance (URL-unique) |
| **State Persistence** | Tab maintains scroll position & selections until closed |
| **Reload Behavior** | Browser refresh resets component to initial state |

**Custom Button Details:**

| Property | Sales_Invoice_Header | Sales_Invoice_Transaction |
|----------|---------------------|--------------------------|
| **Label** | Submit Gift Aid | Submit Gift Aid |
| **Developer Name** | Gift_Aid_Submission | Gift_Aid_Submission |
| **Metadata Location** | weblinks/Sales_Invoice_Header__c.Gift_Aid_Submission.weblink-meta.xml | weblinks/Sales_Invoice_Transaction__c.Gift_Aid_Submission.weblink-meta.xml |
| **Type** | Web Link | Web Link |
| **Link Type** | Custom Tab | Custom Tab |
| **Display Type** | Button | Button |
| **Display Location** | List View | List View |
| **Opens in** | Same window / New tab (per browser) | Same window / New tab (per browser) |
| **Available on** | Desktop & Mobile | Desktop & Mobile |
| **Icon** | Standard or Custom | Standard or Custom |
| **Description** | Bulk Gift Aid submission from invoices | Bulk Gift Aid submission from transactions |

**Browser Behavior:**
```
Tab Already Open:
├─ Click button → Salesforce switches to existing tab
├─ Component state preserved
└─ User sees previously entered filters & selections

Tab Not Open:
├─ Click button → Salesforce creates new tab
├─ Component initializes fresh
├─ Filters reset to defaults
└─ User starts from clean state

Multiple Tabs Open:
├─ Each tab is independent instance
├─ Each maintains separate state
├─ Changes in one tab don't affect others
└─ User can view side-by-side tabs
```

**UI Appearance After Button Click:**
```
Salesforce Dashboard:
┌──────────────────────────────────────────────────────────────┐
│  [Home] [GiftAid...] [Sales_Inv...] ✕  ← Active Tabs         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─ Gift Aid Submission Tab ────────────────────────────┐  │
│  │                                                       │  │
│  │  ┌─ Search Filters ──────────────────────────────┐  │  │
│  │  │ Start Date: [____]  End Date: [____]          │  │  │
│  │  │ Product: [▼]  Status: [Non-Submitted ▼]       │  │  │
│  │  │ Company: [Company ▼]                          │  │  │
│  │  └───────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  ┌─ Transactions List ───────────────────────────┐  │  │
│  │  │ ☐ Date | Reference | Header | Account | ...  │  │  │
│  │  │ ☐ ...  │ ...       │ ...    │ ...     │ ...  │  │  │
│  │  └───────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  [Submit for Gift Aid]  [Clear Filters]             │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

**Permission Requirements:**
```
For button to appear in list view:
├─ User must have READ access to Sales_Invoice_Header__c
│  OR
├─ User must have READ access to Sales_Invoice_Transaction__c
│
AND
│
├─ User must have "Gift Aid" permission set assigned
│  (or equivalent custom permission/profile setting)
│
For button to function:
├─ User must have READ access to Custom Tab "Gift_Aid_Submission__c"
├─ User must have EXECUTE access to giftAidSubmission LWC
└─ User must have READ access to Apex Controller
   (GiftAidSubmissionController)
```

---

#### **Step 1: User Accesses the LWC Component (After Tab Opens)**

**What Happens:**
1. Custom tab is now active in Salesforce
2. `giftAidSubmission` LWC component loads within the tab
3. `connectedCallback()` lifecycle hook is triggered on component insertion
4. Component initializes with data and renders UI

**Details:**
```javascript
Component Lifecycle - connectedCallback() execution:
├─ Component inserted into DOM
├─ Reactive properties (@track) initialized
│
├─ Load default company
│  └─ Call getCurrentUserCompany() (Apex)
│     ├─ Query User's Current_Logged_In_Company__c field
│     └─ Return company name & ID (or empty if not set)
│
├─ Load product filter options
│  └─ getProductFilterOptions() (Apex)
│     └─ Query Product2 WHERE Gift_Aid_Eligible_Products__c = TRUE
│
├─ Load gift aid status options
│  └─ getGiftAidStatusOptions() (Apex)
│     └─ Extract picklist values from
│        Sales_Invoice_Transaction__c.Gift_Aid_Submission_Status__c
│
├─ Load company filter options
│  └─ getCompanyFilterOptions() (Apex)
│     └─ Query Company__c records
│
├─ Call getTransactions() with default filters
│  ├─ No start date (unless pre-populated from button)
│  ├─ No end date (unless pre-populated from button)
│  ├─ No product filter (unless pre-selected from button)
│  ├─ Status: 'Non-Submitted' (default)
│  └─ Company: User's current company (or all if not set)
│
└─ Initialize tracking maps/variables
   ├─ selectedMap = {} (empty Map for cross-page selections)
   ├─ pageNumber = 1
   ├─ pageSize = 10
   ├─ totalPages = calculated from results
   ├─ salesInvoiceTransactionData = []
   ├─ singlePageSalesInvoiceTransactionData = []
   ├─ selectedGiftAidStatus = 'Non-Submitted'
   ├─ isLoading = false
   └─ errorMessage = ''
```

**Database Calls Made:**
1. Query User's company (1 call)
2. Query Gift Aid eligible products (1 call)
3. Query picklist values (1 call)
4. Query companies (1 call)
5. Query eligible contacts + transactions (1 call)
   - Total: **5 Apex calls**
   - Total records returned: 50+ (depending on data volume)

**UI Rendering:**
```
Component Renders in Tab:
├─ Header section: "Gift Aid Submission" title
├─ Filter section:
│  ├─ Start Date input (empty)
│  ├─ End Date input (empty)
│  ├─ Product dropdown (populated from query 2)
│  ├─ Submission Status dropdown (populated from query 3)
│  └─ Company dropdown (pre-selected, populated from query 4)
├─ Data table section:
│  ├─ Column headers (15+ columns)
│  ├─ First page of results (10 records per page)
│  ├─ Pagination controls (Page 1 of X)
│  └─ Select all / row selection checkboxes
├─ Action buttons:
│  ├─ "Submit for Gift Aid" button (disabled if no selection)
│  ├─ "Clear Filters" button
│  └─ "Reset Page" button
└─ Loading indicator: (hidden after data loads)
```

**UI State After Component Load:**
- Filters displayed with default values
- Data table populated with eligible transactions
- Pagination controls ready for user interaction
- No transactions selected yet
- Submit button visible but disabled (grayed out)

---

#### **Step 2: User Sets Filters & Loads Data**

**What Happens:**
1. User optionally enters date range (Start Date - End Date)
2. User selects Product (optional)
3. User selects Submission Status (default: Non-Submitted)
4. User selects Company (default: their company)
5. User clicks "Search" or filter changes trigger load

**Event Handler:**
```javascript
handleDateChange() or handleComboboxChange():
├─ Validate inputs
├─ Build filter parameters
│  ├─ startDate (if entered)
│  ├─ endDate (if entered)
│  ├─ productId (if selected)
│  ├─ giftAidStatus (if different from default)
│  └─ companyId (if different from default)
│
├─ Call getTransactions(startDate, endDate, productId, status, company)
└─ Reset pageNumber to 1
```

**Backend Processing:**
```
getTransactions() execution:

1. Query eligible contacts
   SELECT Id, FirstName, LastName, MailingPostalCode, AccountId
   FROM Contact
   WHERE IsDonor__c = TRUE
     AND Eligible_for_Gift_Aid__c = TRUE
     AND Gift_Aid_Declaration_Date__c < TODAY
     AND Gift_Aid_Expiry_Date__c > TODAY
     AND Donor_Role__c = 'Gift Aid Donor'

   Result: Map of Account ID → Contact (used for donor lookup)

2. Build dynamic query for Sales_Invoice_Transaction__c
   Base fields: (18 fields - ID, Name, Amount, Account Details, Product, Company, etc)

   Base filter: Product__r.Gift_Aid_Eligible_Products__c = TRUE

   Optional filters:
   └─ IF startDate provided: AND Invoice_Date >= startDate
   └─ IF endDate provided: AND Invoice_Date <= endDate
   └─ IF productId provided: AND Product ID = productId
   └─ IF giftAidStatus provided: AND Status = giftAidStatus
   └─ IF companyId provided: AND Company = companyId

   Sort: Invoice_Date DESC

3. Execute dynamic query
   Result: List<Sales_Invoice_Transaction__c> (potentially 100s-1000s)

4. Build wrapper for each transaction
   FOR each transaction:
   ├─ Create GiftAidSubmissionResultWrapper
   ├─ Populate basic fields (ID, Name, Amount)
   ├─ Lookup related header details
   ├─ Lookup related account details
   ├─ Lookup related company details
   ├─ Lookup related product details
   ├─ Lookup donor contact from Account ID
   │  └─ IF contact exists: populate first name, last name, postal code
   │  └─ ELSE: leave empty (no matching donor)
   └─ Add to response list

   Result: List<GiftAidSubmissionResultWrapper> (sanitized data for UI)

5. Return to LWC
```

**Frontend Processing:**
```javascript
// Handle response
this.salesInvoiceTransactionData = resultList;
this.totalPages = Math.ceil(resultList.length / this.pageSize);
this.pageNumber = 1;
this.updatePageData();

// Pagination
updatePageData():
├─ Calculate start & end indices
│  ├─ start = (pageNumber - 1) * pageSize
│  └─ end = Math.min(start + pageSize, totalRecords)
│
├─ Extract page slice
│  └─ this.singlePageSalesInvoiceTransactionData = data[start:end]
│
└─ Render table with page data
   (10 records per page shown)
```

**UI State:**
- Data table populated with first 10 records
- Page indicator shows current page (Page 1 of X)
- Selected rows cleared
- Navigation buttons enabled

---

#### **Step 3: User Selects Transactions**

**What Happens:**
1. User checks checkboxes next to transactions to select them
2. Selection can span multiple pages (selections persist)
3. User can select all on current page or manually select individual rows

**Event Handler:**
```javascript
handleRowSelection(event):
├─ Get selected row IDs from data-table event
├─ FOR each selected ID:
│  └─ Add to selectedMap (Map<String, Boolean>)
│
└─ Display count: "X records selected"

handleSelectAllPages():
├─ FOR each transaction in full dataset:
│  └─ Add ID to selectedMap
│
└─ Display: "All X records selected"
```

**Data Structure:**
```
selectedMap = {
  "0015900000AAA001" → true,
  "0015900000AAA002" → true,
  "0015900000AAA005" → true,
  ...
}

selectedRowsIds = [
  "0015900000AAA001",
  "0015900000AAA002",
  "0015900000AAA005",
  ...
]
```

**Persistence:**
- When user navigates pages, selections retained in selectedMap
- Checkboxes rehydrated based on selectedMap presence

---

#### **Step 4: User Submits for Gift Aid**

**What Happens:**
1. User clicks "Submit for Gift Aid" button
2. Selected transaction IDs passed to Apex

**Validation:**
```javascript
handleSubmitClick():
├─ Validate selectedRowsIds.length > 0
│  └─ IF empty: show error toast "Please select at least one transaction"
│
├─ Confirm submission with user
│  └─ Show confirmation modal
│
└─ IF confirmed:
   ├─ Set isLoading = true (show spinner)
   └─ Call saveSubmission(selectedRowsIds)
```

**Backend Execution:**

**4.1: Fetch Transaction Details**
```
Database.query([
  SELECT Id, Name, Paid_Amount__c,
         Gift_Aid_Submission_Status__c,
         CreatedDate,
         Sales_Invoice_Header__r.Account__r.Id
  FROM Sales_Invoice_Transaction__c
  WHERE Id IN :salesTransactionIds
])

Result: List<Sales_Invoice_Transaction__c> with populated header/account
```

**4.2: Load Configuration**
```
GiftAidSubmission__c gasConstant = GiftAidSubmission__c.getInstance()
├─ senderId → configured value
├─ charityId → HMRC charity number
├─ pass → authentication password
├─ Channel_URI → routing information
├─ Channel_Product & Channel_Version
└─ endpoint → HMRC submission endpoint

Company__c company = [SELECT from current user's company]
├─ Name
├─ Registered_Charity_Number__c
├─ Company_PostalCode__c
└─ Telephone__c
```

**4.3: Map Donor Contacts**
```
Extract all Account IDs from transactions
Query Contact WHERE AccountId IN (:accountIds)
                AND IsDonor__c = TRUE
                AND Eligible_for_Gift_Aid__c = TRUE
                AND Gift_Aid_Declaration_Date__c < TODAY
                AND Gift_Aid_Expiry_Date__c > TODAY

Create Map<Id, Contact> (Account ID → Contact)

Validation:
FOR each transaction:
  IF no contact in map:
    └─ Throw AuraHandledException
       "No eligible donor found for account: {accountName}"
```

**4.4: Build XML Payload**
```
Call buildXmlPayloadString() with:
├─ transactions list
├─ config data map
└─ account → contact map

Generates XML structure:
├─ GovTalk envelope with message headers
├─ Sender authentication details
├─ Charity details and channel routing
└─ Body with R68 form containing:
   ├─ Authorized official info (from company)
   ├─ Claim details (charity name, number)
   └─ GAD entries (one per transaction):
      ├─ Donor personal info (first name, last name, address, postcode)
      ├─ Transaction date
      └─ Transaction amount

XML size: typically 2-5 KB depending on transaction count
```

**4.5: Generate IRmark (Digital Signature)**
```
Call HMRCIRmarkGenerator.processCharitySubmission(xmlPayload):

Step A: Extract namespace from GovTalkMessage
  └─ Regex to find xmlns attribute

Step B: Extract Body content
  └─ Find <Body>...</Body> section

Step C: Add namespace to Body element
  └─ Replace <Body> with <Body xmlns="...">

Step D: Remove IRmark placeholder
  └─ Regex to strip <IRmark>PlaceHolder</IRmark>

Step E: Canonicalize XML (W3C C14N)
  ├─ Remove XML declaration
  ├─ Normalize line endings (CRLF → LF)
  ├─ Remove comments
  ├─ Trim whitespace (preserve internal)
  └─ Result: Deterministic canonical form

Step F: Generate SHA-1 hash
  └─ Hash canonical XML → 20-byte digest

Step G: Encode hash
  ├─ Base64: {hash in base64} (used in XML)
  └─ Base32: {hash in base32} (human-readable)

Step H: Insert IRmark into XML
  └─ Replace PlaceHolder with base64 value

Result: Signed XML payload ready for submission
```

**4.6: Submit to HMRC**
```
HTTP Request:
├─ Method: POST
├─ Endpoint: {custom setting endpoint}
├─ Content-Type: text/xml
└─ Body: Signed XML payload

Processing:
├─ HMRC gateway receives submission
├─ Validates signature
├─ Validates XML structure
├─ Generates unique CorrelationID (Submission Number)
└─ Returns acknowledgement XML

Response XML contains:
├─ CorrelationID (Unique identifier for polling)
├─ MessageDetails with status
└─ May include errors (validation failures)

Response time: Usually 1-5 seconds
Status: 'acknowledgement' received immediately
```

**4.7: Parse Response**
```
Extract XML tags:
├─ CorrelationID → Submission_Number__c
├─ Qualifier → Response type
├─ Function → Message function
└─ Error details (if present)

Store full response in variable
```

**4.8: Create Gift_Aid_Submission__c Record**
```
New Gift_Aid_Submission__c():
├─ Submission_Number__c = CorrelationID (from response)
├─ Submission_Date__c = TODAY
├─ Submitted_By__c = UserInfo.getUserId()
├─ Submission_Response__c = Full XML response
├─ Gift_Aid_Polling_Status__c = 'In Progress'
└─ Polling_Response__c = null (filled by batch later)

Insert into DB → Generates new record ID
```

**4.9: Update Sales_Invoice_Transaction__c Records**
```
FOR each transaction in scope:
├─ Gift_Aid_Submission_Status__c = 'Submitted'
├─ Gift_Aid_Submission__c = New Gift_Aid_Submission__c ID
└─ Other fields unchanged

Update all in batch (not individual DML)
```

**4.10: Return Success**
```
Return 'Success' string to LWC
```

**Frontend Response Handling:**
```javascript
// Apex call completes successfully
.then(result => {
  if (result === 'Success') {
    ├─ Set isLoading = false (hide spinner)
    ├─ Show success toast:
    │  "Gift Aid submission completed successfully!"
    ├─ Clear selectedRowsIds & selectedMap
    ├─ Reset filters
    ├─ Reload transactions
    └─ Navigate to Gift_Aid_Submission__c record
       [NavigationMixin]
       └─ Redirect to record detail page in new tab
  }
})
.catch(error => {
  ├─ Set isLoading = false
  ├─ Show error toast with error message
  └─ Keep current page state (no navigation)
})
```

**UI State After Submission:**
- Loading indicator removed
- Success notification displayed
- Table refreshed to show updated statuses
- Selected transactions now show "Submitted" status
- User can optionally navigate to submission record

---

#### **Step 5: Scheduled Batch Job Polls HMRC**

**When:**
- Scheduler executes at configured intervals (e.g., every 30 minutes, hourly, etc.)
- No user involvement

**What Happens:**

**5.1: Scheduler Execution**
```
Apex Scheduler job triggered at configured time
├─ System runs: GiftAidSubmissionPollScheduler.execute()
└─ Calls: Database.executeBatch(
           new GiftAidSubmissionPollBatch(),
           batch_size = 50)
```

**5.2: Batch Start Phase**
```
GiftAidSubmissionPollBatch.start() executed
└─ Query:
   SELECT Id, Submission_Number__c, Polling_Response__c,
          Gift_Aid_Polling_Status__c, Polling_Error_Description__c,
          (SELECT Id, Gift_Aid_Submission_Status__c
           FROM Sales_Invoice_Transactions__r)
   FROM Gift_Aid_Submission__c
   WHERE Gift_Aid_Polling_Status__c != 'Success'
     AND Gift_Aid_Polling_Status__c != 'Error'

   Result: QueryLocator with all "In Progress" submissions
```

**5.3: Batch Execute Phase (per 50 records)**
```
FOR each Gift_Aid_Submission__c in scope:

Step A: Load Configuration
  ├─ GiftAidSubmission__c.getInstance()
  ├─ endpoint (for delete calls)
  └─ polling_endpoint (for poll calls)

Step B: Call Polling API
  ├─ HTTP POST to polling_endpoint
  ├─ GovTalk request with Submission_Number
  └─ Response: XML with status update

  Request payload:
  <?xml version="1.0" encoding="UTF-8"?>
  <GovTalkMessage xmlns="...">
    <MessageDetails>
      <Class>HMRC-CHAR-CLM</Class>
      <Qualifier>poll</Qualifier>
      <CorrelationID>{Submission_Number}</CorrelationID>
    </MessageDetails>
  </GovTalkMessage>

  Response payload:
  <?xml version="1.0" encoding="UTF-8"?>
  <GovTalkMessage>
    <MessageDetails>
      <CorrelationID>{Submission_Number}</CorrelationID>
      <Qualifier>acknowledgement|response|error</Qualifier>
      <Function>submit</Function>
      [error details if Qualifier=error]
    </MessageDetails>
  </GovTalkMessage>

Step C: Store Response
  ├─ submission.Polling_Response__c = response XML
  └─ Persist in record for audit trail

Step D: Parse Response
  ├─ Extract CorrelationID
  ├─ Extract Qualifier (error/response/acknowledgement)
  └─ Extract Function (must be 'submit')

Step E: Validate CorrelationID Match
  └─ IF CorrelationID != submission.Submission_Number__c:
     └─ Skip processing, continue to next submission

Step F: Evaluate Status

  ┌─────────────────────────────────────┐
  │ CASE 1: Qualifier = 'error'         │
  ├─────────────────────────────────────┤
  │ • Extract error details:            │
  │   - RaisedBy (e.g., "HMRC")        │
  │   - Number (error code)             │
  │   - Type (error type)               │
  │   - Text (error message)            │
  │                                     │
  │ • Build error string:               │
  │   "{RaisedBy} - {Number} - {Type}  │
  │    - {Text}"                        │
  │                                     │
  │ • Update submission:                │
  │   - Polling_Error_Description =     │
  │     error_string                    │
  │   - Gift_Aid_Polling_Status =       │
  │     'Error'                         │
  │                                     │
  │ • Call Delete API:                  │
  │   – Remove from HMRC endpoint       │
  │                                     │
  │ • Update related transactions:      │
  │   FOR each Sales_Invoice_Trans:     │
  │   - Gift_Aid_Submission_Status =    │
  │     'Rejected'                      │
  │                                     │
  │ • Add to update lists               │
  └─────────────────────────────────────┘

  ┌─────────────────────────────────────┐
  │ CASE 2: Qualifier = 'response'      │
  │         & Function = 'submit'       │
  ├─────────────────────────────────────┤
  │ • No error to extract (success)     │
  │                                     │
  │ • Update submission:                │
  │   - Polling_Error_Description =     │
  │     '' (empty)                      │
  │   - Gift_Aid_Polling_Status =       │
  │     'Success'                       │
  │                                     │
  │ • Call Delete API:                  │
  │   – Cleanup: remove from HMRC       │
  │                                     │
  │ • Update related transactions:      │
  │   FOR each Sales_Invoice_Trans:     │
  │   - Gift_Aid_Submission_Status =    │
  │     'Accepted'                      │
  │                                     │
  │ • Add to update lists               │
  └─────────────────────────────────────┘

  ┌─────────────────────────────────────┐
  │ CASE 3: Qualifier = 'acknowledgement'
  ├─────────────────────────────────────┤
  │ • No action required                │
  │                                     │
  │ • Keep status:                      │
  │   - Gift_Aid_Polling_Status =       │
  │     'In Progress'                   │
  │                                     │
  │ • Don't update transactions         │
  │                                     │
  │ • Will poll again next batch cycle  │
  │   (HMRC still processing)           │
  └─────────────────────────────────────┘

Step G: Bulk Update Records
  ├─ Update all modified Gift_Aid_Submission__c
  ├─ Update all modified Sales_Invoice_Transaction__c
  └─ Single DML for performance
```

**5.4: Batch Finish Phase**
```
GiftAidSubmissionPollBatch.finish() called
├─ Log "Batch Completed"
└─ Optional: Send notification email (not implemented)

Records now reflect HMRC final status
```

**Database Impact:**
- 1-2 Gift_Aid_Submission__c records updated per batch execution
- Up to 2000 Sales_Invoice_Transaction__c records updated (status changes)
- Polling_Response__c field populated with latest response

---

#### **Step 6: User Checks Submission Status**

**What Happens:**
1. User can navigate to Gift_Aid_Submission__c record detail page
2. Displays submission status and error details (if present)
3. Can view related Sales_Invoice_Transaction__c records
4. Can view submission/polling responses (read-only)

**Data Visible:**
```
Gift_Aid_Submission__c Record:
├─ Submission_Number__c → Unique HMRC ID
├─ Submission_Date__c → When submitted
├─ Submitted_By__c → User who submitted
├─ Gift_Aid_Polling_Status__c → Current status (Success/Error/In Progress)
├─ Polling_Error_Description__c → Error details (if error)
├─ Submission_Response__c → Initial HMRC response
├─ Polling_Response__c → Latest polling response
└─ Related List: Sales_Invoice_Transactions__r
   ├─ Transaction ID
   ├─ Gift_Aid_Submission_Status__c (Accepted/Rejected)
   └─ Other transaction details
```

---

### Timeline Example

```
Timeline of Complete Gift Aid Submission Cycle:

10:00 AM
  └─ User selects and submits 5 transactions
     └─ Gift_Aid_Submission__c created (ID: GAS-001)
        Status: In Progress
        Submission_Number: CORR-12345-XYZ
     └─ 5 Sales_Invoice_Transaction__c updated
        Status: Submitted

10:30 AM
  └─ Scheduler triggers polling batch (if configured for 30-min intervals)
     └─ callPollingAPI() invoked for GAS-001
        └─ Response: acknowledgement qualifier
           └─ Status stays: In Progress
              (HMRC still validating)

11:00 AM
  └─ Scheduler triggers polling batch again
     └─ callPollingAPI() invoked for GAS-001
        └─ Response: response qualifier (success)
           └─ GAS-001 updated:
              • Status: Success
              • Error description: (empty)
           └─ callDeleteAPI() removes from HMRC queue
           └─ 5 transactions updated:
              • Status: Accepted (all passed validation)

11:30 AM
  └─ Scheduler triggers polling batch
     └─ Query finds: no more "In Progress" submissions
        └─ GAS-001 not queried (already Success)
        └─ No action taken

User View (11:30 AM+):
  └─ Navigates to GAS-001 record
     └─ Sees:
        • Status: Success
        • Related transactions: All Accepted
        • Polling_Response: Contains final positive response
```

---

## External Integrations

### HMRC Gateway Integration

**Provider:** HM Revenue & Customs (HMRC)
**Protocol:** HTTP POST with GovTalk XML format
**Authentication:** SenderID + Password (clear text over HTTPS)

#### Endpoints

| Endpoint Type | Purpose | Environment |
|---------------|---------|-------------|
| **Submission** | Submit Gift Aid claims | HMRC Production/Test |
| **Polling** | Check submission status | HMRC Production/Test |
| **Delete** | Remove submitted claim | HMRC Production/Test |

#### Submission Endpoint

**URL:** (from custom settings - GiftAidSubmission__c.endpoint__c)

**Request:** Signed GovTalk XML
**Response:** XML with CorrelationID and acknowledgement

**Example Response:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<GovTalkMessage>
  <MessageDetails>
    <CorrelationID>CORR-2025-001-ABC123</CorrelationID>
    <Qualifier>acknowledgement</Qualifier>
    <Function>submit</Function>
    <DateTimeStamp>2025-03-05T10:30:00Z</DateTimeStamp>
  </MessageDetails>
</GovTalkMessage>
```

#### Polling Endpoint

**URL:** (from custom settings - GiftAidSubmission__c.polling_endpoint__c)

**Request:** GovTalk XML with CorrelationID

**Response:**  XML with updated status

**Possible Qualifiers:**
- `acknowledgement`: Still processing
- `response`: Success or error details
- `error`: System error

#### Delete Endpoint

**URL:** (from custom settings - GiftAidSubmission__c.endpoint__c with delete function)

**Purpose:** Remove previously submitted message
**Trigger:** After receiving final success or error response

---

### Encryption & OAuth (HMRCIntegrationAPI)

**Security Methods:**

| Method | Algorithm | Purpose |
|--------|-----------|---------|
| AES-128 | Symmetric encryption | Record data encryption (optional) |
| AES-256 | Symmetric encryption | OAuth state encryption |
| SHA-1 | Hash algorithm | IRmark digital signature |

**OAuth Flow (for VAT/other integrations):**
1. User clicks "Connect with HMRC"
2. System redirects to HMRC authorization endpoint
3. User logs in with HMRC credentials
4. HMRC redirects back with authorization code
5. System exchanges code for access token
6. Token stored securely for API calls

**State Encryption:**
```
Original: "company_id$$redirect_url"
Encrypted: AES-256 (with Privatekey + Privatekey)
Encoded: HEX
Sent: In OAuth redirect URL as 'state' parameter
Decrypted: On callback to verify company context
```

---

## Configuration & Settings

### Custom Settings: GiftAidSubmission__c

```
Field Name              Type    Purpose
────────────────────────────────────────────────────────
senderId                Text    HMRC sender authentication ID
charityId               Text    Charity reference number
pass                    Text    Authentication password
endpoint                Text    URL for submission & delete endpoints
polling_endpoint        Text    URL for polling endpoint
Channel_URI             Text    Message channel URI
Channel_Product         Text    Channel product identifier
Channel_Version         Text    Channel version
aednpc__Channel_URI__c  Text    (Alternative naming)
aednpc__Channel_Product__c Text (Alternative naming)
aednpc__Channel_Version__c Text (Alternative naming)
```

### Example Custom Setting Record

```
Name: Default (or per-company/environment)

senderId:           CHARITY_APP
charityId:          CHARID_12345
pass:               SecurePassword123
endpoint:           https://secure.gateway.hmrc.gov.uk/submission
polling_endpoint:   https://secure.gateway.hmrc.gov.uk/retrieve
Channel_URI:        http://www.hmrc.gov.uk/taxation/charities/r68
Channel_Product:    R68_Gift_Aid_Claim
Channel_Version:    1.0
```

### Company (Charity) Configuration

**Required Fields:**
- Name: Charity name (used in submission)
- Registered_Charity_Number__c: HMRC charity number
- Company_PostalCode__c: Postal code
- Telephone__c: Contact telephone

**Example:**
```
Name:                           Acme Charity
Registered_Charity_Number__c:   123456
Company_PostalCode__c:          AB12 3CD
Telephone__c:                   020 7123 4567
```

### Product Configuration

**Required Field:**
- Gift_Aid_Eligible_Products__c = TRUE

**Products with this checked appear in:**
- Filter dropdown (LWC)
- Eligible transaction queries
- Submission payload GAD entries

### Contact Gift Aid Configuration

**Required Fields for Eligibility:**
- IsDonor__c = TRUE
- Eligible_for_Gift_Aid__c = TRUE
- Gift_Aid_Declaration_Date__c < TODAY
- Gift_Aid_Expiry_Date__c > TODAY
- Donor_Role__c = 'Gift Aid Donor'

**Also Required:**
- MailingPostalCode (for XML submission)
- MailingStreet (for XML submission)
- FirstName & LastName (for XML submission)

---

## Dependencies

### Salesforce Platform

| Component | Type | Version Required |
|-----------|------|------------------|
| Lightning Web Components | Feature | API v52+ |
| Apex Classes | Feature | Java-based |
| Batch Apex | Feature | Core platform |
| Custom Objects | Feature | Core platform |
| Custom Metadata | Feature | Core platform |
| HTTP Callouts | Feature | Enterprise+ or Developer |
| Crypto APIs (Crypto, EncodingUtil) | Feature | Core platform |

### Custom Objects Referenced

**Primary Objects:**
- `Gift_Aid_Submission__c` (custom) - Submission records
- `Sales_Invoice_Transaction__c` (custom) - Transaction details
- `Sales_Invoice_Header__c` (custom) - Invoice master

**Standard Objects (Enhanced):**
- `Contact` - Donor information
- `Account` - Customer accounts
- `Product2` - Products/services
- `User` - User authentication & company

**Custom Objects (Related):**
- `Company__c` (aednpc__Company__c) - Charity organizations
- `Aedonco_Setting__mdt` - Encryption keys (custom metadata)

### External Systems

| System | Protocol | Purpose |
|--------|----------|---------|
| HMRC Gateway | HTTPS REST | Gift Aid submission & polling |
| OAuth Provider (HMRC) | HTTPS OAuth 2.0 | Authorization & token exchange |

### Apex Namespaces Used

```apex
// Standard Salesforce
System.debug()
System.log()
UserInfo
Database (executeBatch, getQueryLocator)
Schema (describe fields, picklist values)
EncodingUtil (base64Encode, base32)
Crypto (generateDigest, encrypt)
Dom (XML parsing - optional)

// Custom Namespaces (if configured)
// aednpc.* (AEDON package classes)
```

### Metadata Types Deployed

```
- ApexClass (5 classes)
  • GiftAidSubmissionController
  • GiftAidSubmissionPollBatch
  • GiftAidSubmissionPollScheduler
  • HMRCIntegrationAPI
  • HMRCIRmarkGenerator

- LightningComponentBundle (1 component)
  • giftAidSubmission (LWC)

- CustomObject (2 objects)
  • Gift_Aid_Submission__c
  • GiftAidSubmission__c (deprecated?)

- CustomTab (2 tabs) ⭐ UI ENTRY POINTS
  • Gift_Aid_Submission (Tab for LWC component access)
    ├─ Type: Lightning Web Component Tab
    ├─ Component: giftAidSubmission (LWC)
    ├─ Label: Gift Aid Submission
    └─ Appears in Salesforce Tab Bar

  • Gift_Aid_Submission__c (Standard object tab)

- WebLink (2 web links) ⭐ QUICK ACTION BUTTONS
  • Sales_Invoice_Header__c.Gift_Aid_Submission
    ├─ Label: Submit Gift Aid
    ├─ Type: Custom Tab Link
    ├─ Location: Sales_Invoice_Header__c List View
    ├─ Opens: Gift_Aid_Submission custom tab
    └─ Purpose: Quick access from invoice header list

  • Sales_Invoice_Transaction__c.Gift_Aid_Submission
    ├─ Label: Submit Gift Aid
    ├─ Type: Custom Tab Link
    ├─ Location: Sales_Invoice_Transaction__c List View
    ├─ Opens: Gift_Aid_Submission custom tab
    └─ Purpose: Quick access from transaction list

- RemoteSiteSetting (1 setting)
  • Gift_Aid_Submission (HMRC gateway URL)
    ├─ URL: https://secure.gateway.hmrc.gov.uk/...
    └─ Purpose: Allow Apex callouts to HMRC endpoints

- CustomField (Multiple fields on custom objects)
  • See section on Data Model
```

**Deployment Note:**
The Custom Buttons (WebLinks) and Custom Tab are critical UI entry points:
- Users access Gift Aid Submission functionality from familiar list views
- Buttons appear in list view toolbar for quick access
- Custom tab ensures component loads in the tab bar
- No manual tab pinning required for initial access
```

---

## Error Handling & Recovery

### Input Validation Errors

**Error: No Eligible Donor Found**
```
When: saveSubmission() cannot find Contact for Account
Thrown: AuraHandledException("No eligible donor found for account: {accountName}")
Recovery:
  1. Check Contact eligibility fields
  2. Ensure Gift_Aid_Declaration_Date < TODAY
  3. Ensure Gift_Aid_Expiry_Date > TODAY
  4. Set IsDonor__c = TRUE
  5. Set Eligible_for_Gift_Aid__c = TRUE
  6. Retry submission
```

**Error: Missing Contact Details**
```
When: Contact missing postal code or street
Thrown: AuraHandledException(details)
Recovery:
  1. Update Contact record with full address
  2. Populate MailingPostalCode
  3. Populate MailingStreet
  4. Retry submission
```

**Error: No Transactions Selected**
```
When: selectedRowsIds list is empty
Thrown: Validation in handleSubmitClick()
Recovery:
  1. User must select at least 1 transaction
  2. Check filters are not too restrictive
  3. Ensure transactions exist with status "Non-Submitted" or "Rejected"
  4. Select transactions & retry
```

### HMRC API Errors

**Error: Invalid Digital Signature (IRmark)**
```
HMRC Response: error qualifier with signature validation error
Description: IRmark generation failed or doesn't match expected value
Recovery:
  1. Check canonical XML generation
  2. Verify SHA-1 hash function
  3. Verify base64 encoding
  4. Check HMRC spec compliance
  5. Re-run HMRCIRmarkGenerator tests
  6. Retry submission
```

**Error: Validation Error from HMRC**
```
HMRC Response: error qualifier with validation error details
Description: XML structure doesn't match HMRC schema
Recovery:
  1. Review error message from Polling_Error_Description__c
  2. Check buildXmlPayloadString() structure vs HMRC R68 spec
  3. Validate all required fields are populated
  4. Check donor details (name, address, postcode)
  5. Fix data and retry submission
```

**Error: Authentication Failure**
```
HMRC Response: error qualifier with auth error
Description: Invalid senderID, charityId, or password
Recovery:
  1. Verify GiftAidSubmission__c custom setting values:
     - senderId matches HMRC configuration
     - charityId  matches registered charity ID
     - pass matches HMRC password
  2. Contact HMRC to obtain correct credentials
  3. Update custom settings with correct values
  4. Retry submission
```

**Error: Gateway Timeout**
```
Cause: HTTP callout exceeds timeout or HMRC gateway unavailable
Recovery:
  1. Batch job automatically retries on next scheduled run
  2. Check HMRC gateway status page
  3. If timeout in UI submission: show user "Please try again in a few minutes"
  4. Pending submissions stay in "In Progress" until resolved
```

### Batch Job Errors

**Error: Correlation ID Mismatch**
```
When: Polling response CorrelationID != Submission_Number__c
Action: Submission record skipped, not updated
Recovery:
  1. Manual review of Gift_Aid_Submission__c record
  2. Compare Submission_Number__c with polling response
  3. Decide if manual update needed
  4. Batch will continue processing other submissions
```

**Error: Batch Fails Due to DML Limit**
```
When: Too many records updated in single batch
Recovery:
  1. Batch size already set to 50 (tune if needed)
  2. System automatically splits into multiple batches
  3. Can run multiple batch cycles to complete processing
```

**Error: callout_timeout**
```
When: HTTP callout to HMRC exceeds limit
Recovery:
  1. Next scheduled batch attempts again
  2. Record stays in "In Progress" status
  3. Retried up to system limit
  4. May require manual investigation if persistent
```

### Data Integrity Checks

**Check: Orphaned Gift_Aid_Submission__c**
```
Issue: Submission record exists but no related transactions
Fix:
  - Delete orphaned record, or
  - Manually link transactions
```

**Check: Transaction Status Mismatch**
```
Issue: Multiple Gift_Aid_Submission__c linked to same transaction
Fix:
  - Keep only latest submission
  - Delete duplicate relationships
```

**Check: Approval Deadlock**
```
Issue: Record locked during batch update
Recovery: Batch automatically retries on next execution
```

---

## Security Considerations

### Authentication & Authorization

**HMRC Sender Authentication:**
- Method: SenderID + Password (over HTTPS)
- Not: OAuth or JWT tokens
- Credentials stored in Custom Setting (only accessible to Salesforce admins)

**Salesforce User Authentication:**
- Standard Salesforce authentication required
- LWC available to users with access to Gift Aid permission set (if configured)
- Apex controller: with sharing class (enforces CRUD/FLS)

**Data Access Control:**
```apex
// In GiftAidSubmissionController methods
WITH SECURITY_ENFORCED  // Enforces FLS and CRUD
```

### Data Encryption

**At Rest:**
- Gift_Aid_Submission__c records: Platform encryption (if configured)
- Custom settings: Stored as plaintext (recommend encryption)
- Polling responses: May contain sensitive data (PII)

**In Transit:**
- All HMRC API calls: HTTPS/TLS
- Submission payload: Signed with IRmark digital signature
- OAuth state: AES-256 encrypted

**Sensitive Data in Logs:**
- Avoid logging full XML payloads (contains donor PII)
- Avoid logging auth credentials
- Scrub sensitive fields before debug logging

### IRmark Digital Signature

**Prevents:**
- Man-in-the-middle tampering
- Unauthorized submissions
- Replay attacks

**Implementation:**
- SHA-1 hashing algorithm (per HMRC spec)
- Not using RSA asymmetric signing
- One-way hash (cannot be reverse-engineered)
- Embedded in XML for server-side verification

### Remote Site Settings

**Required Configuration:**
```
Remote Site: Gift_Aid_Submission
URL: https://secure.gateway.hmrc.gov.uk
(or test endpoint during dev)
```

**Security:**
- Only HTTPS endpoints allowed
- Domain whitelisting prevents callouts to unauthorized servers
- Must be configured before deployments

### Field-Level Security

**Sensitive Fields:**
- Gift_Aid_Submission__c.Polling_Error_Description__c
  (Contains error details, PII if validation fails)
- Contact.MailingPostalCode (PII)
- Contact.MailingStreet (PII)

**Recommendation:**
- Restrict field read access to authorized users
- Create permission set for Gift Aid operations
- Audit field access logs

### Batch Job Security

**Batch Execution:**
- Runs as Batch User (system account)
- Executes with ALL permissions (use with sharing in code)
- Can access/update records batch user might not normally see

**Mitigation:**
- Code uses with sharing where appropriate
- Log all batch operations for auditing
- Restrict Apex class access to admins

---

## Testing Strategy

### Unit Tests

#### Test Class: `GiftAidSubmissionControllerTest`

**Test: testGetTransactions_WithFilters**
```apex
// Test filtering by date range, product, status, company
// Verify: Correct records returned, unwanted records excluded
// Coverage: Dynamic query building and filtering logic
```

**Test: testGetTransactions_EligibleContacts**
```apex
// Test donor eligibility checks
// Verify: Only contacts meeting ALL criteria included
// Coverage: Contact eligibility date/flag validation
```

**Test: testSaveSubmission_BuildsCorrectXML**
```apex
// Test XML payload generation
// Verify: All required elements present, donor data correct
// Coverage: buildXmlPayloadString() logic
```

**Test: testSaveSubmission_CreatesGiftAidSubmissionRecord**
```apex
// Test record creation from HMRC response
// Verify: Submission_Number from CorrelationID, Status set to "In Progress"
// Coverage: Record creation and field mapping
```

**Test: testSaveSubmission_UpdatesTransactionStatus**
```apex
// Test transaction status updates after submission
// Verify: All selected transactions marked as "Submitted"
// Coverage: Bulk update logic
```

**Test: testSaveSubmission_ThrowsErrorNoEligibleDonor**
```apex
// Test error handling when donor missing
// Verify: AuraHandledException thrown with correct message
// Coverage: Error path validation
```

#### Test Class: `GiftAidSubmissionPollBatchTest`

**Test: testBatch_ErrorResponse**
```apex
// Mock HMRC error response
// Verify: Submission status = 'Error', Transactions status = 'Rejected'
// Coverage: Error handling path
```

**Test: testBatch_SuccessResponse**
```apex
// Mock HMRC success response
// Verify: Submission status = 'Success', Transactions status = 'Accepted'
// Coverage: Success path
```

**Test: testBatch_AcknowledgementResponse**
```apex
// Mock acknowledgement (still processing)
// Verify: Status remains 'In Progress'
// Coverage: Polling loop path
```

**Test: testBatch_CorrelationIDMismatch**
```apex
// Test with mismatched CorrelationID
// Verify: Submission record not updated
// Coverage: Validation logic
```

**Test: testBatch_CallsDeleteAPI**
```apex
// Verify Delete API called after success or error
// Coverage: Cleanup logic
```

### Integration Tests

**Test: EndToEndSubmission**
```apex
// 1. Create eligible contact & transaction
// 2. Call saveSubmission()
// 3. Mock HMRC response (acknowledgement)
// 4. Verify Gift_Aid_Submission__c created
// 5. Run batch job with mocked polling response (final)
// 6. Verify final status updated
// Coverage: Full user journey
```

**Test: ConcurrentSubmissions**
```apex
// Submit multiple transactions in single batch
// Verify: All processed independently
// Coverage: Batch processing with multiple records
```

### LWC Tests (Jest)

**Test: Component Connection**
```javascript
// Verify connectedCallback() loads options
// Check: Product/Status/Company dropdowns populated
```

**Test: Filter & Data Load**
```javascript
// User sets filters
// Verify: getTransactions() called with correct params
// Check: Data table populated
```

**Test: Pagination**
```javascript
// Load 25+ records
// Verify: Pagination controls appear
// Navigate pages & verify selection persistence
```

**Test: Multi-page Selection**
```javascript
// Select records on multiple pages
// Verify: selectedMap tracks all selections
// Submit & verify all selected IDs sent to Apex
```

**Test: Error Handling**
```javascript
// Mock Apex error response
// Verify: Error toast shown, no navigation
// State remains for retry
```

### Performance Tests

**Test: Large Submission (1000+ transactions)**
```
Test Size: 1000+ Sales_Invoice_Transactions
Measure:
  - Query time: < 2 seconds
  - XML generation time: < 5 seconds
  - HTTP callout time: < 30 seconds
Success Criteria: All complete within timeout limits
```

**Test: Batch Polling (1000+ submissions)**
```
Test Size: 1000+ Gift_Aid_Submission__c
Measure:
  - Batch execute time per 50: < 60 seconds
  - Total batch time: < 10 minutes
Success: All processed within governor limits
```

### Mock Data

**Contact Mock:**
```apex
Contact donor = new Contact(
  FirstName = 'John',
  LastName = 'Donor',
  MailingPostalCode = 'AB12 3CD',
  MailingStreet = '123 Main St',
  IsDonor__c = true,
  Eligible_for_Gift_Aid__c = true,
  Gift_Aid_Declaration_Date__c = Date.today().addDays(-30),
  Gift_Aid_Expiry_Date__c = Date.today().addDays(365),
  Donor_Role__c = 'Gift Aid Donor'
);
```

**Transaction Mock:**
```apex
Sales_Invoice_Transaction__c txn = new Sales_Invoice_Transaction__c(
  Name = 'TXN-001',
  Paid_Amount__c = 100.00,
  Gift_Aid_Submission_Status__c = 'Non-Submitted',
  Sales_Invoice_Header__c = headerId,
  Company__c = companyId,
  Product__c = productId
);
```

**HMRC Mock Response:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<GovTalkMessage>
  <MessageDetails>
    <CorrelationID>CORR-2025-001-XYZ</CorrelationID>
    <Qualifier>acknowledgement</Qualifier>
    <Function>submit</Function>
  </MessageDetails>
</GovTalkMessage>
```

---

## Appendix: Glossary

| Term | Definition |
|------|-----------|
| **AAD** | Authenticated Authorized Official (HMRC term) |
| **Gift Aid** | UK tax relief on charitable donations |
| **GAD** | Gift Aid Declaration (XML element) |
| **GovTalk** | UK government XML messaging standard |
| **HMRC** | HM Revenue & Customs (UK tax authority) |
| **IRmark** | Digital signature for HMRC submissions |
| **LWC** | Lightning Web Component (Salesforce frontend) |
| **PII** | Personally Identifiable Information |
| **R68** | HMRC Gift Aid Declaration form number |
| **TLS/HTTPS** | Encrypted network protocol |

---

## Document Information

**Version History:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-15 | Abhishek D | Initial comprehensive documentation |

**Document Review Checklist:**

- [x] Workflow documented
- [x] Data model described
- [x] Component details explained
- [x] Data flow visualized
- [x] Step-by-step process detailed
- [x] Dependencies listed
- [x] Error handling covered
- [x] Security considerations addressed
- [x] Testing strategy outlined

**Next Steps for Implementation:**

1. Deploy test class and achieve 85%+ code coverage
2. Configure remote site settings for HMRC endpoints
3. Set up custom settings with HMRC credentials
4. Schedule batch job with appropriate frequency
5. Create permission set for Gift Aid operations
6. Document user procedures for submission workflow
7. Set up monitoring for failed submissions
8. Plan knowledge transfer to support team

---

*End of Technical Documentation*
