/**
 * GiftAidSubmissionPollBatch
 *
 * Author: Abhishek D
 * Created Date: 2025-11-22
 * Last Modified By: Abhishek D
 * Last Modified Date: 2025-12-18
 *
 * Description:
 *  Batch class to poll HMRC for Gift Aid submission statuses, handle errors,
 *  update Gift_Aid_Submission__c and related Sales_Invoice_Transaction__c records,
 *  and optionally delete processed submissions from the endpoint.
 */
public class GiftAidSubmissionPollBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /**
     * start
     * Purpose: Provide a QueryLocator for Gift_Aid_Submission__c records that require polling.
     * Returns: Database.QueryLocator for batch processing.
     */
	public Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator([SELECT Id, Submission_Number__c, Polling_Response__c, Gift_Aid_Polling_Status__c, Polling_Error_Description__c, (SELECT Id, Gift_Aid_Submission_Status__c FROM Sales_Invoice_Transactions__r) FROM Gift_Aid_Submission__c WHERE Gift_Aid_Polling_Status__c != 'Success' AND Gift_Aid_Polling_Status__c != 'Error']);
	}

    /**
     * execute
     * Purpose: For each submission in the scope, call the polling API, evaluate response,
     *          set polling status and error description, call delete when required,
     *          and update related Sales Invoice Transaction statuses.
     * Params:
     *  - Database.BatchableContext BC
     *  - List<SObject> scope: batch scope of Gift_Aid_Submission__c records
     */
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

    /**
     * callPollingAPI
     * Purpose: Build and POST a polling GovTalk XML to the polling endpoint and return the response body.
     * Params:
     *  - String submissionNumber: correlation/submission id to poll
     *  - String endpoint: polling endpoint URL
     * Returns: String response body
     */
	private String callPollingAPI(String submissionNumber, String endpoint) {
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

    /**
     * callDeleteAPI
     * Purpose: Build and POST a delete GovTalk XML to the submission endpoint to remove a previously submitted message.
     * Params:
     *  - String submissionNumber: correlation/submission id to delete
     *  - String endpoint: submission/delete endpoint URL
     * Returns: String response body
     */
	private String callDeleteAPI(String submissionNumber, String endpoint) {
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

    /**
     * parseXmlTag
     * Purpose: Extract a simple tag value from a raw XML string (non-robust parser intended for small known responses).
     * Params:
     *  - String xml: raw XML string
     *  - String tagName: tag to extract
     * Returns: String value or null if tag not found
     */
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

    /**
     * finish
     * Purpose: Finalize batch processing. Currently logs completion; extend if post-processing/notifications are needed.
     */
	public void finish(Database.BatchableContext BC) {
		System.debug('Batch Completed');
	}
}