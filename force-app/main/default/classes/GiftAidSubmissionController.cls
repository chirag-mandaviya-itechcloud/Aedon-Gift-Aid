public class GiftAidSubmissionController {
	@AuraEnabled
	public static List<Sales_Invoice_Transaction__c> getTransactions(Datetime startDate, Datetime endDate) {

		String q = 'SELECT Id, Name, CreatedDate, Paid_Amount__c FROM Sales_Invoice_Transaction__c WHERE Gift_Aid_Submitted__c = FALSE AND Product__r.Gift_Aid_Eligible_Products__c = TRUE';

		if (startDate != null && endDate != null) {
			q += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate ';
		}

		q += ' ORDER BY CreatedDate DESC';

		return Database.query(q);
	}

	@AuraEnabled
	public static String saveSubmission(List<Id> salesTransactionIds){
		try {
			List<Sales_Invoice_Transaction__c> salesTransactions = [SELECT Id, Name, aednpc__Paid_Amount__c, aednpc__Gift_Aid_Submitted__c, aednpc__Gift_Aid_Submission__c, CreatedDate FROM aednpc__Sales_Invoice_Transaction__c WHERE Id IN :salesTransactionIds];
			String responseXml = '';

			if(!salesTransactions.isEmpty()) {
				// Build XML Payload
            	String xmlPayload = buildXmlPayload(salesTransactions);
				responseXml = callHMRC(xmlPayload);

				/*
				<?xml version="1.0" encoding="UTF-8"?>
				<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">
					<EnvelopeVersion>2.0</EnvelopeVersion>
					<Header>
						<MessageDetails>
							<Class>HMRC-CHAR-CLM</Class>
							<Qualifier>acknowledgement</Qualifier>
							<Function>submit</Function>
							<TransactionID></TransactionID>
							<CorrelationID>C3C7E00A90B440D59ABDC1C8E011533A</CorrelationID>
							<ResponseEndPoint PollInterval="10">https://test-transaction-engine.tax.service.gov.uk/poll</ResponseEndPoint>
							<GatewayTimestamp>2025-11-21T13:06:33.059</GatewayTimestamp>
						</MessageDetails>
						<SenderDetails/>
					</Header>
					<GovTalkDetails>
						<Keys/>
					</GovTalkDetails>
					<Body/>
				</GovTalkMessage>
				*/
			}
			return responseXml;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static String buildXmlPayload(List<Sales_Invoice_Transaction__c> txns) {
		Dom.Document doc = new Dom.Document();
		// root element
		Dom.XmlNode root = doc.createRootElement('GovTalkMessage', null, null);
		root.setAttribute('xmlns', 'http://www.govtalk.gov.uk/CM/envelope');
		// EnvelopVersion element
		root.addChildElement('EnvelopeVersion', null, null).addTextNode('2.0');

		// Header element
		Dom.XmlNode header = root.addChildElement('Header', null, null);
		Dom.XmlNode msgDetails = header.addChildElement('MessageDetails', null, null);
		msgDetails.addChildElement('Class', null, null).addTextNode('HMRC-CHAR-CLM');
		msgDetails.addChildElement('Qualifier', null, null).addTextNode('request');
		msgDetails.addChildElement('Function', null, null).addTextNode('submit');
		msgDetails.addChildElement('TransactionID', null, null);
		msgDetails.addChildElement('GatewayTest', null, null).addTextNode('1');

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
		irEnvelope.setAttribute('xmlns', 'http://www.govtalk.gov.uk/IR/envelope');
		irEnvelope.setAttribute('xmlns:r68', 'http://www.govtalk.gov.uk/taxation/charities/r68/2');

		Dom.XmlNode irHeader = irEnvelope.addChildElement('IRheader', null, null);
		Dom.XmlNode irKeys = irHeader.addChildElement('Keys', null, null);
		Dom.XmlNode irKey = irKeys.addChildElement('Key', null, null);
		irKey.setAttribute('Type', 'CHARID');
		irKey.addTextNode('AB12345');

		irHeader.addChildElement('Sender', null, null).addTextNode('Company');
		Dom.XmlNode irMark = irHeader.addChildElement('IRmark', null, null);
		irMark.setAttribute('Type', 'generic');
		irMark.addTextNode('OYI0...ABC=');

		irHeader.addChildElement('GatewayTimestamp', null, null);

		// R68 Claim Section
        Dom.XmlNode r68 = irEnvelope.addChildElement(
            'r68:R68',
            null,
            null
        );

		Dom.XmlNode claim = r68.addChildElement('Claim', null, null);
		claim.addChildElement('HMRCref', null, null).addTextNode('AB12345');

		Dom.XmlNode repayment = claim.addChildElement('Repayment', null, null);
        repayment.addChildElement('NumberOfDonations', null, null)
                 .addTextNode(String.valueOf(txns.size()));

		Decimal total = 0;
        for (Sales_Invoice_Transaction__c t : txns) {
            total += t.Paid_Amount__c;
        }
        repayment.addChildElement('TotalDonationAmount', null, null)
                 .addTextNode(String.valueOf(total));

		// GAD Entries
        for (Sales_Invoice_Transaction__c t : txns) {
			Dom.XmlNode gad = repayment.addChildElement('GAD', null, null);

            Dom.XmlNode donor = gad.addChildElement('Donor', null, null);
            donor.addChildElement('Ttl', null, null).addTextNode('');
            donor.addChildElement('Forename', null, null).addTextNode('');
            donor.addChildElement('Surname', null, null).addTextNode('');
            donor.addChildElement('HouseName', null, null).addTextNode('');
            donor.addChildElement('Postcode', null, null).addTextNode('');

            gad.addChildElement('DonationDate', null, null)
               .addTextNode(String.valueOf(t.CreatedDate));

            gad.addChildElement('DonationAmount', null, null)
               .addTextNode(String.valueOf(t.Paid_Amount__c));
		}
		return doc.toXmlString();
	}

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
}
