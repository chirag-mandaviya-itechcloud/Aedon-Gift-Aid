public class GiftAidSubmissionController {

    @AuraEnabled
	public static List<Sales_Invoice_Transaction__c> getTransactions(Date startDate, Date endDate) {

        List<Contact> donorContacts = [SELECT AccountId FROM Contact WHERE IsDonor__c = TRUE];

        List<Id> donorAccIds = new List<Id>();

        for (Contact con : donorContacts) {
            donorAccIds.add(con.AccountId);
        }

        String q = 'SELECT Id, Sales_Invoice_Header__r.Name, Name, Company__r.Name, Sales_Invoice_Header__r.Invoice_Date__c, Sales_Invoice_Header__r.Account__r.Name, Customer_Reference__c, Product__r.Name, Nominal_Code2__r.Nominal_Code__c, Sale_VAT__r.Name, Analysis_1__r.Name, Analysis_2__r.Name, Paid_Amount__c FROM Sales_Invoice_Transaction__c WHERE Gift_Aid_Submitted__c = FALSE AND Product__r.Gift_Aid_Eligible_Products__c = TRUE AND Sales_Invoice_Header__r.Account__r.Id IN :donorAccIds';

		if (startDate != null && endDate != null) {
			q += ' AND Sales_Invoice_Header__r.Invoice_Date__c >= :startDate AND Sales_Invoice_Header__r.Invoice_Date__c <= :endDate ';
		}

		q += ' ORDER BY Sales_Invoice_Header__r.Invoice_Date__c DESC';

		return Database.query(q);
	}

	@AuraEnabled
	public static String saveSubmission(List<Id> salesTransactionIds){
        try {
			List<Sales_Invoice_Transaction__c> salesTransactions = [SELECT Id, Name, Paid_Amount__c, Gift_Aid_Submitted__c, Gift_Aid_Submission__c, CreatedDate, Sales_Invoice_Header__r.Account__r.Id FROM Sales_Invoice_Transaction__c WHERE Id IN :salesTransactionIds];
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

                List<Contact> donorContacts = [SELECT Id, AccountId, FirstName, LastName, MailingPostalCode, MailingStreet FROM Contact WHERE AccountId IN :selectedDonorAccIds AND IsDonor__c = TRUE];

                for (Contact con : donorContacts) {
                    accToConMap.put(con.AccountId, con);
                }

				// Build XML Payload
            	String xmlPayload = buildXmlPayloadString(salesTransactions,configData, accToConMap);

                String updateXml = HMRCIRmarkGenerator.processCharitySubmission(xmlPayload);

				System.debug('updateXml: ' + updateXml);
				responseXml = callHMRC(updateXml);
                System.debug('responseXml: ' + responseXml);

				String submissionId = parseXmlTag(responseXml, 'CorrelationID');

				Gift_Aid_Submission__c giftAidRecord = new Gift_Aid_Submission__c();
				giftAidRecord.Submission_Number__c = submissionId;
				giftAidRecord.Submission_Date__c = Date.today();
				giftAidRecord.Submitted_By__c = UserInfo.getUserId();
				giftAidRecord.Submission_Response__c = responseXml;

				insert giftAidRecord;

				for(Sales_Invoice_Transaction__c sit : salesTransactions) {
					sit.Gift_Aid_Submitted__c = true;
					sit.Gift_Aid_Submission__c = giftAidRecord.Id;
				}

				update salesTransactions;
			}
			return 'Success';
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

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
            //<GatewayTimestamp>'+Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS')+'</GatewayTimestamp>
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
	/*private static String buildXmlPayload(List<Sales_Invoice_Transaction__c> txns) {
		Dom.Document doc = new Dom.Document();
		Dom.XmlNode root = doc.createRootElement('GovTalkMessage', null, null);
		root.setAttribute('xmlns', 'http://www.govtalk.gov.uk/CM/envelope');
		root.addChildElement('EnvelopeVersion', null, null).addTextNode('2.0');

		// Header element
		Dom.XmlNode header = root.addChildElement('Header', null, null);
		Dom.XmlNode msgDetails = header.addChildElement('MessageDetails', null, null);
		msgDetails.addChildElement('Class', null, null).addTextNode('HMRC-CHAR-CLM');
		msgDetails.addChildElement('Qualifier', null, null).addTextNode('request');
		msgDetails.addChildElement('Function', null, null).addTextNode('submit');
		msgDetails.addChildElement('CorrelationID', null, null);
        msgDetails.addChildElement('Transformation', null, null).addTextNode('XML');
		msgDetails.addChildElement('GatewayTest', null, null).addTextNode('1');
        msgDetails.addChildElement('GatewayTimestamp', null, null).addTextNode(Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS'));

		// SenderDetails element
		Dom.XmlNode senderDetails = header.addChildElement('SenderDetails', null, null);
		Dom.XmlNode idAuth = senderDetails.addChildElement('IDAuthentication', null, null);
		idAuth.addChildElement('SenderID', null, null).addTextNode('323412300001');

		Dom.XmlNode auth = idAuth.addChildElement('Authentication', null, null);
		auth.addChildElement('Method', null, null).addTextNode('clear');
        auth.addChildElement('Role', null, null).addTextNode('principal');
        auth.addChildElement('Value', null, null).addTextNode('testing1');

		// GovTalkDetails
		Dom.XmlNode govTalkDetails = root.addChildElement('GovTalkDetails', null, null);
		Dom.XmlNode keys = govTalkDetails.addChildElement('Keys', null, null);
		Dom.XmlNode key = keys.addChildElement('Key', null, null);
		key.setAttribute('Type', 'CHARID');
		key.addTextNode('AB12345');

		// Body
		Dom.XmlNode body = root.addChildElement('Body', null, null);
		Dom.XmlNode irEnvelope = body.addChildElement(
            'IRenvelope', null, null
        );
		irEnvelope.setAttribute('xmlns', 'http://www.govtalk.gov.uk/taxation/charities/r68/2');

		Dom.XmlNode irHeader = irEnvelope.addChildElement('IRheader', null, null);
		Dom.XmlNode irKeys = irHeader.addChildElement('Keys', null, null);
		Dom.XmlNode irKey = irKeys.addChildElement('Key', null, null);
		irKey.setAttribute('Type', 'CHARID');
		irKey.addTextNode('AB12345');
		irHeader.addChildElement('PeriodEnd', null, null).addTextNode(Datetime.now().formatGMT('yyyy-MM-dd'));
        irHeader.addChildElement('DefaultCurrency', null, null).addTextNode('GBP');
		Dom.XmlNode irMark = irHeader.addChildElement('IRmark', null, null);
		irMark.setAttribute('Type', 'generic');
		irMark.addTextNode('PLACEHOLDER');
        irHeader.addChildElement('Sender', null, null).addTextNode('Company');

		//irHeader.addChildElement('GatewayTimestamp', null, null);

		// R68 Claim Section
        Dom.XmlNode r68 = irEnvelope.addChildElement(
            'R68',
            null,
            null
        );

        Dom.XmlNode authOfficial = r68.addChildElement('AuthOfficial', null, null);
        Dom.XmlNode OffName = authOfficial.addChildElement('OffName', null, null);
        OffName.addChildElement('Fore', null, null).addTextNode('John');
        OffName.addChildElement('Sur', null, null).addTextNode('Smith');

        Dom.XmlNode OffID = authOfficial.addChildElement('OffID', null, null);
        OffID.addChildElement('Postcode', null, null).addTextNode('AB12 3CD');

        authOfficial.addChildElement('Phone', null, null).addTextNode('01234 567890');

        r68.addChildElement('Declaration', null, null).addTextNode('yes');

		Dom.XmlNode claim = r68.addChildElement('Claim', null, null);
        claim.addChildElement('OrgName', null, null).addTextNode('My Organisation');
		claim.addChildElement('HMRCref', null, null).addTextNode('AB12345');

        Dom.XmlNode Regulator = claim.addChildElement('Regulator', null, null);
        Regulator.addChildElement('RegName', null, null).addTextNode('CCEW');
		Regulator.addChildElement('RegNo', null, null).addTextNode('A1234');

		Dom.XmlNode repayment = claim.addChildElement('Repayment', null, null);
        //repayment.addChildElement('NumberOfDonations', null, null)
       //          .addTextNode(String.valueOf(txns.size()));

		//Decimal total = 0;
       // for (Sales_Invoice_Transaction__c t : txns) {
       //     total += t.Paid_Amount__c;
       // }
       // repayment.addChildElement('TotalDonationAmount', null, null)
       //          .addTextNode(String.valueOf(total));
		///
        DateTime EarliestGAdate = DateTime.now();
		// GAD Entries
        for (Sales_Invoice_Transaction__c t : txns) {
			Dom.XmlNode gad = repayment.addChildElement('GAD', null, null);

            Dom.XmlNode donor = gad.addChildElement('Donor', null, null);
            //donor.addChildElement('Ttl', null, null).addTextNode('');
            donor.addChildElement('Fore', null, null).addTextNode('Jane');
            donor.addChildElement('Sur', null, null).addTextNode('Smith');
            donor.addChildElement('House', null, null).addTextNode('1');
            donor.addChildElement('Postcode', null, null).addTextNode('BA23 9CD');

            gad.addChildElement('Date', null, null)
               .addTextNode(t.CreatedDate.formatGMT('yyyy-MM-dd'));

            gad.addChildElement('Total', null, null)
               .addTextNode(String.valueOf(t.Paid_Amount__c));

            if(EarliestGAdate > t.CreatedDate) {
                EarliestGAdate = t.CreatedDate;
            }
		}
        repayment.addChildElement('EarliestGAdate', null, null).addTextNode(EarliestGAdate.formatGMT('yyyy-MM-dd'));

        return doc.toXmlString();
	}*/

    private static String callHMRC(String xmlPayload) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://test-transaction-engine.tax.service.gov.uk/submission');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml');
        req.setBody(xmlPayload);

        HttpResponse res = http.send(req);
        return res.getBody();
    }

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
		/*Dom.Document doc = new Dom.Document();
		doc.load(xml);
		Dom.XmlNode root = doc.getRootElement();

		Dom.XmlNode target = findNode(root, tagName);
		return target != null ? target.getText() : null;*/
	}

	private static Dom.XmlNode findNode(Dom.XmlNode node, String tagName) {
		if (node.getName() == tagName) return node;

		for (Dom.XmlNode child : node.getChildElements()) {
			Dom.XmlNode result = findNode(child, tagName);
			if (result != null) return null;
		}
		return null;
	}

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
}
