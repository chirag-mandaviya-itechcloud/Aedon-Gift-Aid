public class GiftAidSubmissionPollBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
	public Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator([SELECT Id, Submission_Number__c, Polling_Response__c, Gift_Aid_Polling_Status__c, Polling_Error_Description__c, (SELECT Id, Gift_Aid_Submission_Status__c FROM Sales_Invoice_Transactions__r) FROM Gift_Aid_Submission__c WHERE Gift_Aid_Polling_Status__c != 'Success' AND Gift_Aid_Polling_Status__c != 'Error']);
	}

	public void execute(Database.BatchableContext BC, List<SObject> scope) {
		List<Gift_Aid_Submission__c> submissionRecords = new List<Gift_Aid_Submission__c>();
		List<Sales_Invoice_Transaction__c> sitRecords = new List<Sales_Invoice_Transaction__c>();

		if (scope.size() > 0) {
			submissionRecords = (List<Gift_Aid_Submission__c>)scope;
		}

		if (!submissionRecords.isEmpty()) {
			GiftAidSubmission__c gasConstant = GiftAidSubmission__c.getInstance();
			String submissionEndpoint = gasConstant.endpoint__c;
			String pollingEndpoint = gasConstant.polling_endpoint__c;

			for (Gift_Aid_Submission__c gas : submissionRecords) {
				String responseBody = callPollingAPI(gas.Submission_Number__c, pollingEndpoint);
				gas.Polling_Response__c = responseBody;

				String correlationId = parseXmlTag(responseBody, 'CorrelationID');

				if (correlationId == gas.Submission_Number__c) {

					String qualifier = parseXmlTag(responseBody, 'Qualifier');
					String function = parseXmlTag(responseBody, 'Function');

					if (qualifier == 'error' && function == 'submit') {
						String errorRaisedBy = parseXmlTag(responseBody, 'RaisedBy');
						String errorNumber = parseXmlTag(responseBody, 'Number');
						String errorType = parseXmlTag(responseBody, 'Type');
						String errorText = parseXmlTag(responseBody, 'Text');

						gas.Polling_Error_Description__c = errorRaisedBy + ' - ' + errorNumber + ' - ' + errorType + ' - ' + errorText;
						gas.Gift_Aid_Polling_Status__c = 'Error';
						String deleteResponse = callDeleteAPI(gas.Submission_Number__c, submissionEndpoint);

						if (gas.Sales_Invoice_Transactions__r.size() > 0) {
							for (Sales_Invoice_Transaction__c sit : gas.Sales_Invoice_Transactions__r) {
								sit.Gift_Aid_Submission_Status__c = 'Rejected';
								sitRecords.add(sit);
							}
						}
					} else if (qualifier == 'response' && function == 'submit') {
						gas.Polling_Error_Description__c = '';
						gas.Gift_Aid_Polling_Status__c = 'Success';
						String deleteResponse = callDeleteAPI(gas.Submission_Number__c, submissionEndpoint);

						if (gas.Sales_Invoice_Transactions__r.size() > 0) {
							for (Sales_Invoice_Transaction__c sit : gas.Sales_Invoice_Transactions__r) {
								sit.Gift_Aid_Submission_Status__c = 'Accepted';
								sitRecords.add(sit);
							}
						}
					} else if (qualifier == 'acknowledgement' && function == 'submit') {
						gas.Gift_Aid_Polling_Status__c = 'In Progress';
					}
				}
			}

			update submissionRecords;
			update sitRecords;
		}
	}

	private String callPollingAPI(String submissionNumber, string endpoint) {
		String requestBodyXml =
			'<?xml version="1.0" encoding="UTF-8"?>' +
			'<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
			'<EnvelopeVersion>2.0</EnvelopeVersion>' +
			'<Header>' +
			'<MessageDetails>' +
			'<Class>HMRC-CHAR-CLM</Class>' +
			'<Qualifier>poll</Qualifier>' +
			'<Function>submit</Function>' +
			'<CorrelationID>' + submissionNumber + '</CorrelationID>' +
			'<Transformation>XML</Transformation>' +
			'</MessageDetails>' +
			'</Header>' +
			'<GovTalkDetails><Keys/></GovTalkDetails>' +
			'</GovTalkMessage>';

		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(endpoint);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'text/xml');
		req.setBody(requestBodyXml);

		HttpResponse res = http.send(req);
		return res.getBody();
	}

	private String callDeleteAPI(String submissionNumber, string endpoint) {
		String requestBodyXml =
			'<?xml version="1.0" encoding="UTF-8"?>' +
			'<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
			'<EnvelopeVersion>2.0</EnvelopeVersion>' +
			'<Header>' +
			'<MessageDetails>' +
			'<Class>HMRC-CHAR-CLM</Class>' +
			'<Qualifier>request</Qualifier>' +
			'<Function>delete</Function>' +
			'<CorrelationID>' + submissionNumber + '</CorrelationID>' +
			'<Transformation>XML</Transformation>' +
			'</MessageDetails>' +
			'</Header>' +
			'<GovTalkDetails><Keys/></GovTalkDetails>' +
			'</GovTalkMessage>';

		Http http = new Http();
		HttpRequest req = new HttpRequest();
		req.setEndpoint(endpoint);
		req.setMethod('POST');
		req.setHeader('Content-Type', 'text/xml');
		req.setBody(requestBodyXml);

		HttpResponse res = http.send(req);
		return res.getBody();
	}

	private String parseXmlTag(String xml, String tagName) {
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

	public void finish(Database.BatchableContext BC) {
		System.debug('Batch Completed');
	}
}