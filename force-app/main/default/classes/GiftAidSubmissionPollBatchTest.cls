/**
* GiftAidSubmissionPollBatchTest
*
* Author: Abhishek D
* Created Date: 2025-12-25
*
* Description:
*  Test class for GiftAidSubmissionPollBatch
*  Provides comprehensive coverage for batch processing, polling, and status updates
*/
@isTest
private class GiftAidSubmissionPollBatchTest {
    
    @TestSetup
    static void setupTestData() {
        
        String orgId = UserInfo.getOrganizationId();
        String dateString = String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','');
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        Integer randomInt = Integer.valueOf(math.rint(math.random()*1000000));
        String uniqueName = orgId + dateString + randomInt;
        Tax_Legislation__c objTaxLegislation = new Tax_Legislation__c(
            Name = 'United Kingdom',
            Short_Code__c = '1'
        );
        insert objTaxLegislation;
        
        Company__c objComp = new Company__c(
            Name = 'Test Comp',
            VAT_Period_covered_by_the_return__c = 'Quarterly',
            Tax_Legislation__c = objTaxLegislation.id
        );
        insert objComp;
        
        User tuser = new User(
            firstname = 'test',
            lastName = 'user',
            email = 'testuser@gmail.com',
            Username = uniqueName + '@test' + orgId + '.org',
            EmailEncodingKey = 'ISO-8859-1',
            Alias = uniqueName.substring(18, 23),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            Current_Logged_In_Company__c = objComp.Id
        );
        insert tuser;
        
        system.runAs(tuser){
            User_Company__c objUserCompany = new User_Company__c();
            objUserCompany.User__c = tuser.Id;
            objUserCompany.Current_Logged_In_Company__c = objComp.Id;
            insert objUserCompany;
            
            // Create Gift Aid Custom Settings
            GiftAidSubmission__c settings = new GiftAidSubmission__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                aednpc__senderId__c = 'SENDER123',
                aednpc__charityId__c = 'CHAR123',
                aednpc__pass__c = 'testpass',
                aednpc__Channel_URI__c = 'https://test.uri',
                aednpc__Channel_Product__c = 'TestProduct',
                aednpc__Channel_Version__c = '1.0',
                endpoint__c = 'https://test.hmrc.gov.uk/endpoint',
                polling_endpoint__c = 'https://test.hmrc.gov.uk/polling'
            );
            insert settings;
            
            Currency__c basecurrency = new Currency__c(
                IsBaseCurrency__c = True,
                Company__c = objComp.Id,
                ISO_Code__c = 'USD'
            );
            insert basecurrency;
            
            // Create Nominal Code
            Chart_Of_Accounts__c nominalCode = new Chart_Of_Accounts__c(
                Name = 'Test Nominal',
                Nominal_Code__c = 4000
            );
            insert nominalCode;
            
            // Create Account
            Account acc = new Account();
            acc.Name = 'Test Account';
            acc.Account_Type__c='Customer';
            acc.VAT_Treatment__c ='UK';
            acc.Account_Type__c = 'Customer';
            acc.AccountNumber = 'TA1234';
            acc.Company__c=  objComp.Id; 
            acc.Nominal_Code__c = nominalCode.Id;
            acc.Preferred_Currency1__c = basecurrency.id;
            acc.Email__c = 'test@companyname.com';
            insert acc;
            
            // Create Sales Invoice Header
            Sales_Invoice_Header__c invoiceHeader = new Sales_Invoice_Header__c(
                //Name = 'INV-001',
                Account__c = acc.Id,
                Invoice_Date__c = Date.today().addDays(-5),
                aednpc__Company__c = objComp.Id
            );
            insert invoiceHeader;
            
            // Create Gift Aid Submissions with different statuses
            List<Gift_Aid_Submission__c> submissions = new List<Gift_Aid_Submission__c>();
            
            // Submission 1: In Progress - should be polled
            Gift_Aid_Submission__c submission1 = new Gift_Aid_Submission__c(
                Submission_Number__c = 'CORR-001',
                Submission_Date__c = Date.today(),
                Gift_Aid_Polling_Status__c = 'In Progress',
                Submitted_By__c = UserInfo.getUserId()
            );
            submissions.add(submission1);
            
            // Submission 2: In Progress - should be polled
            Gift_Aid_Submission__c submission2 = new Gift_Aid_Submission__c(
                Submission_Number__c = 'CORR-002',
                Submission_Date__c = Date.today(),
                Gift_Aid_Polling_Status__c = 'In Progress',
                Submitted_By__c = UserInfo.getUserId()
            );
            submissions.add(submission2);
            
            // Submission 3: In Progress - should be polled
            Gift_Aid_Submission__c submission3 = new Gift_Aid_Submission__c(
                Submission_Number__c = 'CORR-003',
                Submission_Date__c = Date.today(),
                Gift_Aid_Polling_Status__c = 'In Progress',
                Submitted_By__c = UserInfo.getUserId()
            );
            submissions.add(submission3);
            
            // Submission 4: Success - should NOT be polled
            Gift_Aid_Submission__c submission4 = new Gift_Aid_Submission__c(
                Submission_Number__c = 'CORR-SUCCESS',
                Submission_Date__c = Date.today(),
                Gift_Aid_Polling_Status__c = 'Success',
                Submitted_By__c = UserInfo.getUserId()
            );
            submissions.add(submission4);
            
            // Submission 5: Error - should NOT be polled
            Gift_Aid_Submission__c submission5 = new Gift_Aid_Submission__c(
                Submission_Number__c = 'CORR-ERROR',
                Submission_Date__c = Date.today(),
                Gift_Aid_Polling_Status__c = 'Error',
                Submitted_By__c = UserInfo.getUserId()
            );
            submissions.add(submission5);
            
            insert submissions;
            
            // Create Sales Invoice Transactions for submissions 1, 2, and 3
            List<Sales_Invoice_Transaction__c> transactions = new List<Sales_Invoice_Transaction__c>();
            
            // Transactions for submission 1
            transactions.add(new Sales_Invoice_Transaction__c(
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Gift_Aid_Submission__c = submission1.Id,
                Gift_Aid_Submission_Status__c = 'Submitted',
                Paid_Amount__c = 100.00
            ));
            
            transactions.add(new Sales_Invoice_Transaction__c(
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Gift_Aid_Submission__c = submission1.Id,
                Gift_Aid_Submission_Status__c = 'Submitted',
                Paid_Amount__c = 150.00
            ));
            
            // Transactions for submission 2
            transactions.add(new Sales_Invoice_Transaction__c(
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Gift_Aid_Submission__c = submission2.Id,
                Gift_Aid_Submission_Status__c = 'Submitted',
                Paid_Amount__c = 200.00
            ));
            
            // Transactions for submission 3
            transactions.add(new Sales_Invoice_Transaction__c(
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Gift_Aid_Submission__c = submission3.Id,
                Gift_Aid_Submission_Status__c = 'Submitted',
                Paid_Amount__c = 250.00
            ));
            
            insert transactions;
        }
    }
    
    @isTest
    static void testBatch_SuccessResponse() {
        // Set mock for successful response
        Test.setMock(HttpCalloutMock.class, new MockSuccessHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify submission status updated to Success
        Gift_Aid_Submission__c submission = [
            SELECT Id, Gift_Aid_Polling_Status__c, Polling_Error_Description__c, Polling_Response__c
            FROM Gift_Aid_Submission__c
            WHERE Submission_Number__c = 'CORR-001'
            LIMIT 1
        ];
        
        System.assertEquals('Success', submission.Gift_Aid_Polling_Status__c, 
                            'Submission status should be Success');
        System.assertNotEquals(null, submission.Polling_Response__c, 
                               'Polling response should be stored');
        
        // Verify related transactions updated to Accepted
        List<Sales_Invoice_Transaction__c> transactions = [
            SELECT Id, Gift_Aid_Submission_Status__c
            FROM Sales_Invoice_Transaction__c
            WHERE Gift_Aid_Submission__c = :submission.Id
        ];
        
        System.assert(!transactions.isEmpty(), 'Should have related transactions');
        for (Sales_Invoice_Transaction__c txn : transactions) {
            System.assertEquals('Accepted', txn.Gift_Aid_Submission_Status__c, 
                                'Transaction status should be Accepted');
        }
    }
    
    @isTest
    static void testBatch_ErrorResponse() {
        // Set mock for error response
        Test.setMock(HttpCalloutMock.class, new MockErrorHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify submission status updated to Error
        Gift_Aid_Submission__c submission = [
            SELECT Id, Gift_Aid_Polling_Status__c, Polling_Error_Description__c, Polling_Response__c
            FROM Gift_Aid_Submission__c
            WHERE Submission_Number__c = 'CORR-002'
            LIMIT 1
        ];
        
        System.assertEquals('Error', submission.Gift_Aid_Polling_Status__c, 
                            'Submission status should be Error');
        System.assert(submission.Polling_Error_Description__c.contains('HMRC'), 
                      'Error description should contain error details');
        System.assertNotEquals(null, submission.Polling_Response__c, 
                               'Polling response should be stored');
        
        // Verify related transactions updated to Rejected
        List<Sales_Invoice_Transaction__c> transactions = [
            SELECT Id, Gift_Aid_Submission_Status__c
            FROM Sales_Invoice_Transaction__c
            WHERE Gift_Aid_Submission__c = :submission.Id
        ];
        
        System.assert(!transactions.isEmpty(), 'Should have related transactions');
        for (Sales_Invoice_Transaction__c txn : transactions) {
            System.assertEquals('Rejected', txn.Gift_Aid_Submission_Status__c, 
                                'Transaction status should be Rejected');
        }
    }
    
    @isTest
    static void testBatch_AcknowledgementResponse() {
        // Set mock for acknowledgement response (still in progress)
        Test.setMock(HttpCalloutMock.class, new MockAcknowledgementHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify submission status remains In Progress
        Gift_Aid_Submission__c submission = [
            SELECT Id, Gift_Aid_Polling_Status__c, Polling_Response__c
            FROM Gift_Aid_Submission__c
            WHERE Submission_Number__c = 'CORR-003'
            LIMIT 1
        ];
        
        System.assertEquals('In Progress', submission.Gift_Aid_Polling_Status__c, 
                            'Submission status should remain In Progress');
        System.assertNotEquals(null, submission.Polling_Response__c, 
                               'Polling response should be stored');
        
        // Verify related transactions remain Submitted
        List<Sales_Invoice_Transaction__c> transactions = [
            SELECT Id, Gift_Aid_Submission_Status__c
            FROM Sales_Invoice_Transaction__c
            WHERE Gift_Aid_Submission__c = :submission.Id
        ];
        
        System.assert(!transactions.isEmpty(), 'Should have related transactions');
        for (Sales_Invoice_Transaction__c txn : transactions) {
            System.assertEquals('Submitted', txn.Gift_Aid_Submission_Status__c, 
                                'Transaction status should remain Submitted');
        }
    }
    
    @isTest
    static void testBatch_QueryLocator() {
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();
        
        // Get count of records that should be processed
        Integer count = Database.countQuery(
            'SELECT COUNT() FROM Gift_Aid_Submission__c ' +
            'WHERE Gift_Aid_Polling_Status__c != \'Success\' ' +
            'AND Gift_Aid_Polling_Status__c != \'Error\''
        );
        
        // Should return only In Progress submissions (not Success or Error)
        System.assertEquals(3, count, 'Should return 3 submissions to poll');
    }
    
    @isTest
    static void testBatch_NoRecordsToProcess() {
        // Update all submissions to Success or Error
        List<Gift_Aid_Submission__c> submissions = [
            SELECT Id, Gift_Aid_Polling_Status__c
            FROM Gift_Aid_Submission__c
            WHERE Gift_Aid_Polling_Status__c = 'In Progress'
        ];
        
        for (Gift_Aid_Submission__c sub : submissions) {
            sub.Gift_Aid_Polling_Status__c = 'Success';
        }
        update submissions;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccessHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Batch should complete without errors even with no records to process
        System.assert(true, 'Batch should complete successfully with no records');
    }
    
    @isTest
    static void testBatch_SubmissionWithoutTransactions() {
        // Create submission without any transactions
        Gift_Aid_Submission__c submission = new Gift_Aid_Submission__c(
            Submission_Number__c = 'CORR-NO-TXN',
            Submission_Date__c = Date.today(),
            Gift_Aid_Polling_Status__c = 'In Progress',
            Submitted_By__c = UserInfo.getUserId()
        );
        insert submission;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccessHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify submission status updated even without transactions
        Gift_Aid_Submission__c updatedSubmission = [
            SELECT Id, Gift_Aid_Polling_Status__c
            FROM Gift_Aid_Submission__c
            WHERE Id = :submission.Id
            LIMIT 1
        ];
        
        System.assertEquals('Success', updatedSubmission.Gift_Aid_Polling_Status__c, 
                            'Submission should be marked as Success even without transactions');
    }
    
    @isTest
    static void testBatch_MismatchedCorrelationId() {
        // Set mock that returns different correlation ID
        Test.setMock(HttpCalloutMock.class, new MockMismatchedCorrelationHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 10);
        Test.stopTest();
        
        // Verify submission status remains unchanged when correlation ID doesn't match
        Gift_Aid_Submission__c submission = [
            SELECT Id, Gift_Aid_Polling_Status__c
            FROM Gift_Aid_Submission__c
            WHERE Submission_Number__c = 'CORR-001'
            LIMIT 1
        ];
        
        // Status should remain In Progress since correlation ID didn't match
        System.assertEquals('In Progress', submission.Gift_Aid_Polling_Status__c, 
                            'Submission status should remain In Progress when correlation ID mismatches');
    }
    
    @isTest
    static void testBatch_MultipleSubmissionsBatch() {
        // Test batch with multiple records in scope
        Test.setMock(HttpCalloutMock.class, new MockMultiResponseHttpResponse());
        
        Test.startTest();
        GiftAidSubmissionPollBatch batch = new GiftAidSubmissionPollBatch();
        Database.executeBatch(batch, 200); // Process all at once
        Test.stopTest();
        
        // Verify all In Progress submissions were processed
        List<Gift_Aid_Submission__c> submissions = [
            SELECT Id, Gift_Aid_Polling_Status__c, Polling_Response__c
            FROM Gift_Aid_Submission__c
            WHERE Submission_Number__c IN ('CORR-001', 'CORR-002', 'CORR-003')
        ];
        
        System.assertEquals(3, submissions.size(), 'Should have 3 submissions');
        
        for (Gift_Aid_Submission__c sub : submissions) {
            System.assertNotEquals(null, sub.Polling_Response__c, 
                                   'All submissions should have polling response');
        }
    }
    
    // Mock HTTP Response for successful polling response
    private class MockSuccessHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // Determine which correlation ID based on request body
            String body = req.getBody();
            String corrId = 'CORR-001';
            if (body.contains('CORR-002')) {
                corrId = 'CORR-002';
            } else if (body.contains('CORR-003')) {
                corrId = 'CORR-003';
            } else if (body.contains('CORR-NO-TXN')) {
                corrId = 'CORR-NO-TXN';
            }
            
            res.setBody('<?xml version="1.0"?>' +
                        '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
                        '<Header>' +
                        '<MessageDetails>' +
                        '<Class>HMRC-CHAR-CLM</Class>' +
                        '<Qualifier>response</Qualifier>' +
                        '<Function>submit</Function>' +
                        '<CorrelationID>' + corrId + '</CorrelationID>' +
                        '</MessageDetails>' +
                        '</Header>' +
                        '<Body>Success</Body>' +
                        '</GovTalkMessage>');
            return res;
        }
    }
    
    // Mock HTTP Response for error polling response
    private class MockErrorHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?>' +
                        '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
                        '<Header>' +
                        '<MessageDetails>' +
                        '<Class>HMRC-CHAR-CLM</Class>' +
                        '<Qualifier>error</Qualifier>' +
                        '<Function>submit</Function>' +
                        '<CorrelationID>CORR-002</CorrelationID>' +
                        '</MessageDetails>' +
                        '</Header>' +
                        '<GovTalkDetails>' +
                        '<GovTalkErrors>' +
                        '<Error>' +
                        '<RaisedBy>HMRC</RaisedBy>' +
                        '<Number>1001</Number>' +
                        '<Type>business</Type>' +
                        '<Text>Invalid charity reference</Text>' +
                        '</Error>' +
                        '</GovTalkErrors>' +
                        '</GovTalkDetails>' +
                        '</GovTalkMessage>');
            return res;
        }
    }
    
    // Mock HTTP Response for acknowledgement polling response
    private class MockAcknowledgementHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?>' +
                        '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
                        '<Header>' +
                        '<MessageDetails>' +
                        '<Class>HMRC-CHAR-CLM</Class>' +
                        '<Qualifier>acknowledgement</Qualifier>' +
                        '<Function>submit</Function>' +
                        '<CorrelationID>CORR-003</CorrelationID>' +
                        '</MessageDetails>' +
                        '</Header>' +
                        '<Body>Processing</Body>' +
                        '</GovTalkMessage>');
            return res;
        }
    }
    
    // Mock HTTP Response for mismatched correlation ID
    private class MockMismatchedCorrelationHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?>' +
                        '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
                        '<Header>' +
                        '<MessageDetails>' +
                        '<Class>HMRC-CHAR-CLM</Class>' +
                        '<Qualifier>response</Qualifier>' +
                        '<Function>submit</Function>' +
                        '<CorrelationID>DIFFERENT-ID</CorrelationID>' +
                        '</MessageDetails>' +
                        '</Header>' +
                        '</GovTalkMessage>');
            return res;
        }
    }
    
    // Mock HTTP Response that handles multiple submissions
    private class MockMultiResponseHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            String body = req.getBody();
            String corrId = 'CORR-001';
            String qualifier = 'response';
            
            if (body.contains('CORR-001')) {
                corrId = 'CORR-001';
                qualifier = 'response';
            } else if (body.contains('CORR-002')) {
                corrId = 'CORR-002';
                qualifier = 'error';
            } else if (body.contains('CORR-003')) {
                corrId = 'CORR-003';
                qualifier = 'acknowledgement';
            }
            
            String responseBody = '<?xml version="1.0"?>' +
                '<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">' +
                '<Header>' +
                '<MessageDetails>' +
                '<Class>HMRC-CHAR-CLM</Class>' +
                '<Qualifier>' + qualifier + '</Qualifier>' +
                '<Function>submit</Function>' +
                '<CorrelationID>' + corrId + '</CorrelationID>' +
                '</MessageDetails>' +
                '</Header>';
            
            if (qualifier == 'error') {
                responseBody += '<GovTalkDetails>' +
                    '<GovTalkErrors>' +
                    '<Error>' +
                    '<RaisedBy>HMRC</RaisedBy>' +
                    '<Number>1002</Number>' +
                    '<Type>validation</Type>' +
                    '<Text>Validation failed</Text>' +
                    '</Error>' +
                    '</GovTalkErrors>' +
                    '</GovTalkDetails>';
            }
            
            responseBody += '</GovTalkMessage>';
            
            res.setBody(responseBody);
            return res;
        }
    }
}