/**
 * GiftAidSubmissionController
 *
 * Author: Abhishek D
 * Created Date: 2025-11-22
 * Last Modified By: Abhishek D
 * Last Modified Date: 2025-12-18
 *
 * Description:
 *  Controller for Gift Aid submission LWC and backend processing.
 *  - Provides methods to fetch eligible Sales Invoice Transactions,
 *    build and submit HMRC XML payloads, and helper utilities.
 */
public class GiftAidSubmissionController {

    /**
     * getTransactions
     * Purpose: Return a list of Sales Invoice Transaction wrappers for the UI.
     * Params:
     *  - Date startDate: optional filter start date (inclusive)
     *  - Date endDate: optional filter end date (inclusive)
     * Returns: List<GiftAidSubmissionResultWrapper> - formatted records for LWC consumption
     * Notes: Filters transactions by donor eligibility and product eligibility.
     */
	@AuraEnabled
	public static List<GiftAidSubmissionResultWrapper> getTransactions(Date startDate, Date endDate, String productId, String giftAidStatus, String companyId) {

        Map<Id, Contact> accIdToConMap = new Map<Id, Contact>();

        for (Contact con : [SELECT Id, FirstName,  LastName, MailingPostalCode, AccountId FROM Contact WHERE IsDonor__c = TRUE AND Eligible_for_Gift_Aid__c = TRUE AND Gift_Aid_Declaration_Date__c < TODAY AND Gift_Aid_Expiry_Date__c > TODAY AND Donor_Role__c = 'Gift Aid Donor']) {
            if (con.AccountId != null) {
                accIdToConMap.put(con.AccountId, con);
            }
        }

        Set<Id> donorAccIds = accIdToConMap.keySet();
        List<String> allowedStatus = new List<String>{'Non-Submitted', 'Rejected'};
        String q = 'SELECT Id, Sales_Invoice_Header__r.Name, Name, Company__r.Name, Sales_Invoice_Header__r.Invoice_Date__c, Sales_Invoice_Header__r.Account__r.Id, Sales_Invoice_Header__r.Account__r.Name, Customer_Reference__c, Product__r.Name, Nominal_Code2__r.Nominal_Code__c, Sale_VAT__r.Name, Analysis_1__r.Name, Analysis_2__r.Name, Analysis_6__r.Name, Analysis_7__r.Name, Paid_Amount__c FROM Sales_Invoice_Transaction__c WHERE Product__r.Gift_Aid_Eligible_Products__c = TRUE';

		if (startDate != null) {
			q += ' AND Sales_Invoice_Header__r.Invoice_Date__c >= :startDate ';
		}

        if (endDate != null) {
            q += ' AND Sales_Invoice_Header__r.Invoice_Date__c <= :endDate ';
        }

		if (productId != null && productId != '') {
			q += ' AND Product__r.Id = :productId ';
		}

        if (giftAidStatus != null && giftAidStatus != '') {
            q += ' AND Gift_Aid_Submission_Status__c = :giftAidStatus ';
        }

        if (companyId != null && companyId != '') {
            q += ' AND Company__c = :companyId ';
        }

		q += ' ORDER BY Sales_Invoice_Header__r.Invoice_Date__c DESC';

        List<Sales_Invoice_Transaction__c> transactions = Database.query(q);

		List<GiftAidSubmissionResultWrapper> response = new List<GiftAidSubmissionResultWrapper>();

        for (Sales_Invoice_Transaction__c txn : transactions) {
            GiftAidSubmissionResultWrapper wrapper = new GiftAidSubmissionResultWrapper();

            wrapper.Id = txn.Id;
            wrapper.salesInvoiceHeaderName = txn.Sales_Invoice_Header__r.Name;
            wrapper.name = txn.Name;
            wrapper.companyName = txn.Company__r.Name;
            wrapper.invoiceDate = txn.Sales_Invoice_Header__r.Invoice_Date__c;
            wrapper.accountName = txn.Sales_Invoice_Header__r.Account__r.Name;
            wrapper.customerReference = txn.Customer_Reference__c;
            wrapper.productName = txn.Product__r.Name;
            wrapper.nominalCode = txn.Nominal_Code2__r.Nominal_Code__c;
            wrapper.salesVAT = txn.Sale_VAT__r.Name;
            wrapper.analysis1 = txn.Analysis_1__r.Name;
            wrapper.analysis2 = txn.Analysis_2__r.Name;
            wrapper.analysis6 = txn.Analysis_6__r.Name;
            wrapper.analysis7 = txn.Analysis_7__r.Name;
            wrapper.paidAmount = txn.Paid_Amount__c;
            wrapper.contactFirstName = accIdToConMap.containsKey(txn.Sales_Invoice_Header__r.Account__r.Id) ? accIdToConMap.get(txn.Sales_Invoice_Header__r.Account__r.Id).FirstName : '';
            wrapper.contactLastName = accIdToConMap.containsKey(txn.Sales_Invoice_Header__r.Account__r.Id) ? accIdToConMap.get(txn.Sales_Invoice_Header__r.Account__r.Id).LastName : '';
            wrapper.contactPostalCode = accIdToConMap.containsKey(txn.Sales_Invoice_Header__r.Account__r.Id) ? accIdToConMap.get(txn.Sales_Invoice_Header__r.Account__r.Id).MailingPostalCode : '';

            response.add(wrapper);
        }

        return response;
	}

    @AuraEnabled
    public static List<Product2> getProductFilterOptions() {
        return [SELECT Id, Gift_Aid_Eligible_Products__c, Name FROM Product2 WHERE Gift_Aid_Eligible_Products__c = TRUE];
    }

    @AuraEnabled
    public static List<Company__c> getCompanyFilterOptions() {
        return [SELECT Id, Name FROM Company__c ORDER BY Name];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGiftAidStatusOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        Schema.DescribeFieldResult fieldResult = Sales_Invoice_Transaction__c.Gift_Aid_Submission_Status__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', entry.getLabel());
                option.put('value', entry.getValue());
                options.add(option);
            }
        }
        
        return options;
    }

    /**
     * getCurrentUserCompany
     * Purpose: Get the current logged-in user's company
     * Returns: Map<String, String> - Contains companyId and companyName
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCurrentUserCompany() {
        try {
            // Step 1: Get current user's company ID (string field)
            User currentUser = [
                SELECT Id, Name, aednpc__Current_Logged_In_Company__c
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            Map<String, String> result = new Map<String, String>();
            
            // Step 2: Check if user has a company assigned
            if (String.isNotBlank(currentUser.aednpc__Current_Logged_In_Company__c)) {
                // Step 3: Query the Company object using the company ID
                List<aednpc__Company__c> companies = [
                    SELECT Id, Name 
                    FROM aednpc__Company__c 
                    WHERE Id = :currentUser.aednpc__Current_Logged_In_Company__c 
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                
                // Step 4: If company found, return the details
                if (!companies.isEmpty()) {
                    result.put('companyId', companies[0].Id);
                    result.put('companyName', companies[0].Name);
                    System.debug('Current User Company: ' + companies[0].Name + ' (' + companies[0].Id + ')');
                } else {
                    System.debug('No company found with ID: ' + currentUser.aednpc__Current_Logged_In_Company__c);
                }
            } else {
                System.debug('User does not have a Current_Logged_In_Company__c assigned');
            }
            
            return result;
        } catch (Exception e) {
            System.debug('Error fetching current user company: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return new Map<String, String>();
        }
    }

    /**
     * saveSubmission
     * Purpose: Create a Gift_Aid_Submission__c record, build HMRC XML payload and send to HMRC endpoint.
     * Params:
     *  - List<Id> salesTransactionIds: ids of Sales_Invoice_Transaction__c to submit
     * Returns: String - 'Success' on success or throws AuraHandledException on failure
     * Behavior:
     *  - Gathers company and donor contact data, builds payload, calls HMRC and updates SIT statuses.
     */
	@AuraEnabled
	public static String saveSubmission(List<Id> salesTransactionIds){
        try {
			List<Sales_Invoice_Transaction__c> salesTransactions = [SELECT Id, Name, Paid_Amount__c, Gift_Aid_Submission_Status__c, Gift_Aid_Submission__c, CreatedDate, Sales_Invoice_Header__r.Account__r.Id FROM Sales_Invoice_Transaction__c WHERE Id IN :salesTransactionIds];
            String responseXml = '';

            GiftAidSubmission__c gas = GiftAidSubmission__c.getInstance();
            Company__c com= getCompanyInformation();

            Map<String, String> configData = new Map<String, String>();
            configData.put('senderId', gas.aednpc__senderId__c);
            configData.put('charityId', gas.aednpc__charityId__c);
            configData.put('pass', gas.aednpc__pass__c);
            configData.put('RegName', com.Name);
            configData.put('RegNo', com.Registered_Charity_Number__c);
            configData.put('OrgName', com.Name);

            configData.put('Channel_URI', gas.aednpc__Channel_URI__c);
            configData.put('Channel_Product', gas.aednpc__Channel_Product__c);
            configData.put('Channel_Version', gas.aednpc__Channel_Version__c);

            configData.put('AuthOfficial_Fore', com.Name);
            configData.put('AuthOfficial_Sur', com.Name);
            configData.put('AuthOfficial_Postcode', com.Company_PostalCode__c);
            configData.put('AuthOfficial_Phone', com.Telephone__c);

            configData.put('isTest', 'true');

            System.debug('configData: '+ configData);

			if(!salesTransactions.isEmpty()) {
                List<Id> selectedDonorAccIds = new List<Id>();
                Map<Id, Contact> accToConMap = new Map<Id, Contact>();

                for (Sales_Invoice_Transaction__c t : salesTransactions) {
                    selectedDonorAccIds.add(t.Sales_Invoice_Header__r.Account__r.Id);
                }

                List<Contact> donorContacts = [SELECT Id, AccountId, FirstName, LastName, MailingPostalCode, MailingStreet FROM Contact WHERE AccountId IN :selectedDonorAccIds AND IsDonor__c = TRUE AND Eligible_for_Gift_Aid__c = TRUE AND Gift_Aid_Declaration_Date__c < TODAY AND Gift_Aid_Expiry_Date__c > TODAY];

                for (Contact con : donorContacts) {
                    accToConMap.put(con.AccountId, con);
                }

				// Build XML Payload
            	String xmlPayload = buildXmlPayloadString(salesTransactions,configData, accToConMap);

                String updateXml = HMRCIRmarkGenerator.processCharitySubmission(xmlPayload);

				System.debug('updateXml: ' + updateXml);
				responseXml = callHMRC(updateXml, gas.endpoint__c);
                System.debug('responseXml: ' + responseXml);

				String submissionId = parseXmlTag(responseXml, 'CorrelationID');

				Gift_Aid_Submission__c giftAidRecord = new Gift_Aid_Submission__c();
				giftAidRecord.Submission_Number__c = submissionId;
				giftAidRecord.Submission_Date__c = Date.today();
				giftAidRecord.Submitted_By__c = UserInfo.getUserId();
				giftAidRecord.Submission_Response__c = responseXml;
                giftAidRecord.Gift_Aid_Polling_Status__c = 'In Progress';

				insert giftAidRecord;

				for(Sales_Invoice_Transaction__c sit : salesTransactions) {
					sit.Gift_Aid_Submission_Status__c = 'Submitted';
					sit.Gift_Aid_Submission__c = giftAidRecord.Id;
				}

				update salesTransactions;
			}
			return 'Success';
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

    /**
     * buildXmlPayloadString
     * Purpose: Build the HMRC GovTalk XML payload string for the provided transactions.
     * Params:
     *  - List<Sales_Invoice_Transaction__c> txns: transactions to include
     *  - Map<String,String> configData: configuration values (charity id, sender id, etc.)
     *  - Map<Id, Contact> accToConMap: mapping of Account Id -> Contact (donor details)
     * Returns: String - XML payload ready for signing/processing
     */
    private static String buildXmlPayloadString(List<Sales_Invoice_Transaction__c> txns,Map<String,String> configData, Map<Id, Contact> accToConMap) {
        String xml =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
            '<EnvelopeVersion>2.0</EnvelopeVersion>' +
            '<Header>' +
            '<MessageDetails>' +
            '<Class>HMRC-CHAR-CLM</Class>' +
            '<Qualifier>request</Qualifier>' +
            '<Function>submit</Function>' +
            '<CorrelationID/>' +
            '<Transformation>XML</Transformation>' +
            '<GatewayTest>1</GatewayTest>'+
            '</MessageDetails>' +
            '<SenderDetails>' +
            '<IDAuthentication>' +
            '<SenderID>'+configData.get('senderId')+'</SenderID>' +
            '<Authentication>' +
            '<Method>clear</Method>' +
            '<Role>principal</Role>' +
            '<Value>'+configData.get('pass')+'</Value>' +
            '</Authentication>' +
            '</IDAuthentication>' +
            '</SenderDetails>' +
            '</Header>' +
            '<GovTalkDetails>' +
            '<Keys>' +
            '<Key Type="CHARID">'+configData.get('charityId')+'</Key>' +
            '</Keys>' +
            '<TargetDetails>' +
            '<Organisation>HMRC</Organisation>' +
            '</TargetDetails>' +
            '<ChannelRouting>' +
            '<Channel>' +
            '<URI>'+configData.get('Channel_URI')+'</URI>' +
            '<Product>'+configData.get('Channel_Product')+'</Product>' +
            '<Version>'+configData.get('Channel_Version')+'</Version>' +
            '</Channel>' +
            '</ChannelRouting>' +
            '</GovTalkDetails>' +
            '<Body>' +
            '<IRenvelope xmlns="http://www.govtalk.gov.uk/taxation/charities/r68/2">' +
            '<IRheader>' +
            '<Keys>' +
            '<Key Type="CHARID">'+configData.get('charityId')+'</Key>' +
            '</Keys>' +
            '<PeriodEnd>'+Datetime.now().adddays(60).formatGMT('yyyy-MM-dd')+'</PeriodEnd>' +
            '<DefaultCurrency>GBP</DefaultCurrency>' +
            '<IRmark Type="generic">PlaceHolder</IRmark>' +
            '<Sender>Individual</Sender>' +
            '</IRheader>' +
            '<R68>' +
            '<AuthOfficial>' +
            '<OffName>' +
            '<Fore>'+configData.get('AuthOfficial_Fore')+'</Fore>' +
            '<Sur>'+configData.get('AuthOfficial_Sur')+'</Sur>' +
            '</OffName>' +
            '<OffID>' +
            '<Postcode>'+configData.get('AuthOfficial_Postcode')+'</Postcode>' +
            '</OffID>' +
            '<Phone>'+configData.get('AuthOfficial_Phone')+'</Phone>' +
            '</AuthOfficial>' +
            '<Declaration>yes</Declaration>' +
            '<Claim>' +
            '<OrgName>'+configData.get('OrgName')+'</OrgName>' +
            '<HMRCref>'+configData.get('charityId')+'</HMRCref>' +
            '<Regulator>' +
            '<RegName>'+configData.get('RegName')+'</RegName>' +
            '<RegNo>'+configData.get('RegNo')+'</RegNo>' +
            '</Regulator>' +
            '<Repayment>';

        DateTime EarliestGAdate = DateTime.now();
        // GAD Entries
        for (Sales_Invoice_Transaction__c t : txns) {

            Contact txnConDetails = accToConMap.get(t.Sales_Invoice_Header__r.Account__r.Id);
            if (txnConDetails != null) {
                xml += '<GAD>' +
                    '<Donor>' +
                    '<Fore>'+txnConDetails.FirstName+'</Fore>' +
                    '<Sur>'+txnConDetails.LastName+'</Sur>' +
                    '<House>'+txnConDetails.MailingStreet+'</House>' +
                    '<Postcode>'+txnConDetails.MailingPostalCode+'</Postcode>' +
                    '</Donor>' +
                    '<Date>'+t.CreatedDate.formatGMT('yyyy-MM-dd')+'</Date>' +
                    '<Total>'+String.valueOf(t.Paid_Amount__c)+'</Total>' +
                    '</GAD>';

                if(EarliestGAdate > t.CreatedDate) {
                    EarliestGAdate = t.CreatedDate;
                }
            }
        }

        xml += '<EarliestGAdate>'+ EarliestGAdate.formatGMT('yyyy-MM-dd') +'</EarliestGAdate>' +

            '</Repayment>' +
            '</Claim>' +
            '</R68>' +
            '</IRenvelope>' +
            '</Body>' +
            '</GovTalkMessage>';
        return  xml;
    }

    private static String callHMRC(String xmlPayload, String endpoint) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml');
        req.setBody(xmlPayload);

        HttpResponse res = http.send(req);
        return res.getBody();
    }

	/**
	 * parseXmlTag
	 * Purpose: Extract text value between <tagName>...</tagName> from a raw XML string.
	 * Params:
	 *  - String xml: raw XML response
	 *  - String tagName: tag to extract
	 * Returns: String - extracted value or null if not found
	 */
	private static String parseXmlTag(String xml, String tagName) {
        // Tag names
        String startTag = '<'+tagName+'>';
        String endTag   = '</'+tagName+'>';

        // Find positions
        Integer startPos = xml.indexOf(startTag);
        Integer endPos   = xml.indexOf(endTag);

        // Extract value (only if tag exists)
        String correlationId = (startPos > -1 && endPos > -1)
            ? xml.substring(startPos + startTag.length(), endPos)
            : null;
		return correlationId;
	}

	/**
	 * findNode
	 * Purpose: Recursive helper to find a Dom.XmlNode with the specified tagName.
	 * Params:
	 *  - Dom.XmlNode node: current node to search
	 *  - String tagName: name of node to find
	 * Returns: Dom.XmlNode or null
	 */
	private static Dom.XmlNode findNode(Dom.XmlNode node, String tagName) {
		if (node.getName() == tagName) return node;

		for (Dom.XmlNode child : node.getChildElements()) {
			Dom.XmlNode result = findNode(child, tagName);
			if (result != null) return null;
		}
		return null;
	}

    /**
     * getCompanyInformation
     * Purpose: Retrieve the Company__c associated with the current user's Current_Logged_In_Company__c.
     * Returns: Company__c (empty instance if not found)
     * Notes: Uses WITH SECURITY_ENFORCED to honor field-level and object-level security.
     */
    private static Company__c getCompanyInformation(){
        Company__c companyObj = new Company__c();
        List<User> usersList = [SELECT ID, Name, Current_Logged_In_Company__c FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED];
        if(usersList.size() > 0){
            if(usersList[0].Current_Logged_In_Company__c != null){
            	companyObj = [SELECT Name, Registered_Charity_Number__c, Company_PostalCode__c, Telephone__c  FROM Company__c where Id =: usersList[0].Current_Logged_In_Company__c WITH SECURITY_ENFORCED];
            }
        }
        return companyObj;
    }

    /**
     * GiftAidSubmissionResultWrapper
     * Purpose: Wrapper DTO returned to LWC with sanitized and formatted transaction fields.
     */
    public class GiftAidSubmissionResultWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String salesInvoiceHeaderName;
        @AuraEnabled public String name;
        @AuraEnabled public String companyName;
        @AuraEnabled public Date invoiceDate;
        @AuraEnabled public String accountName;
        @AuraEnabled public String customerReference;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal nominalCode;
        @AuraEnabled public String salesVAT;
        @AuraEnabled public String analysis1;
        @AuraEnabled public String analysis2;
        @AuraEnabled public String analysis6;
        @AuraEnabled public String analysis7;
        @AuraEnabled public Decimal paidAmount;
        @AuraEnabled public String giftAidSubmissionStatus;
        @AuraEnabled public String contactFirstName;
        @AuraEnabled public String contactLastName;
        @AuraEnabled public String contactPostalCode;
    }
}