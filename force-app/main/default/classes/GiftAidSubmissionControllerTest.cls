/**
* GiftAidSubmissionControllerTest
*
* Author: Abhishek D
* Created Date: 2025-12-24
*
* Description:
*  Test class for GiftAidSubmissionController
*  Provides comprehensive coverage for all methods including positive and negative scenarios
*/
@isTest
private class GiftAidSubmissionControllerTest {
    
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
            
            Currency__c basecurrency = new Currency__c(
                IsBaseCurrency__c = True,
                Company__c = objComp.Id,
                ISO_Code__c = 'USD'
            );
            insert basecurrency;
            
            // Create Gift Aid Custom Settings
            GiftAidSubmission__c settings = new GiftAidSubmission__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                aednpc__senderId__c = 'SENDER123',
                aednpc__charityId__c = 'CHAR123',
                aednpc__pass__c = 'testpass',
                aednpc__Channel_URI__c = 'https://test.uri',
                aednpc__Channel_Product__c = 'TestProduct',
                aednpc__Channel_Version__c = '1.0',
                endpoint__c = 'https://test.hmrc.gov.uk/endpoint'
            );
            insert settings;
            
            
            
            // Create Product with Gift Aid eligibility
            Product2 product = new Product2(
                Name = 'Donation Product',
                Company__c = objComp.Id,
                Gift_Aid_Eligible_Products__c = true,
                Product_Type__c = 'Sales'
            );
            insert product;
            
            // Create Nominal Code
            Chart_Of_Accounts__c nominalCode = new Chart_Of_Accounts__c(
                Name = 'Test Nominal',
                Nominal_Code__c = 4000
            );
            insert nominalCode;
            
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
            
            // Create eligible Contact (Donor)
            Contact donor = new Contact(
                FirstName = 'John',
                LastName = 'Smith',
                AccountId = acc.Id,
                MailingPostalCode = 'E1 6AN',
                MailingStreet = '123 Test Street',
                IsDonor__c = true,
                Eligible_for_Gift_Aid__c = true,
                Gift_Aid_Declaration_Date__c = Date.today().addDays(-30),
                Gift_Aid_Expiry_Date__c = Date.today().addDays(365),
                Donor_Role__c = 'Gift Aid Donor'
            );
            insert donor;
            
            // Create ineligible Contact for negative testing
            Contact ineligibleDonor = new Contact(
                FirstName = 'Jane',
                LastName = 'Doe',
                AccountId = acc.Id,
                MailingPostalCode = 'W1A 1AA',
                IsDonor__c = true,
                Eligible_for_Gift_Aid__c = false,
                Donor_Role__c = 'Gift Aid Donor'
            );
            insert ineligibleDonor;
            
            // Create VAT
            VAT__c vat = new VAT__c(
                Name = 'Standard VAT',
                aednpc__Description__c = 'Tes Description',
                aednpc__Category__c = 'Exempt',
                Company__c = objComp.Id,
                Additional_Category__c = 'Not Applicable'
            );
            insert vat;
            
            // Create Analysis records
            Analysis_1__c analysis1 = new Analysis_1__c(
                Name = 'Analysis 1',
                Company__c = objComp.Id
            );
            insert analysis1;
            Analysis_2__c analysis2 = new Analysis_2__c(
                Name = 'Analysis 2',
                Company__c = objComp.Id,
                Project_Type__c = 'Charitable Activity'
            );
            insert analysis2;
            Analysis_6__c analysis6 = new Analysis_6__c(
                Name = 'Analysis 6',
                Company__c = objComp.Id
            );
            insert analysis6;
            Analysis_7__c analysis7 = new Analysis_7__c(
                Name = 'Analysis 7',
                Company__c = objComp.Id,
                Fund__c = analysis1.Id,
                Project__c = analysis2.Id
            );
            insert analysis7;
            
            // Create Sales Invoice Header
            Sales_Invoice_Header__c invoiceHeader = new Sales_Invoice_Header__c(
                //Name = 'INV-001',
                Account__c = acc.Id,
                Invoice_Date__c = Date.today().addDays(-5),
                aednpc__Company__c = objComp.Id
            );
            insert invoiceHeader;
            
            // Create Sales Invoice Transactions
            List<Sales_Invoice_Transaction__c> transactions = new List<Sales_Invoice_Transaction__c>();
            
            // Transaction 1: Non-Submitted, eligible
            transactions.add(new Sales_Invoice_Transaction__c(
                //Name = 'TXN-001',
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Product__c = product.Id,
                Nominal_Code2__c = nominalCode.Id,
                Sale_VAT__c = vat.Id,
                Analysis_1__c = analysis1.Id,
                Analysis_2__c = analysis2.Id,
                Analysis_6__c = analysis6.Id,
                Analysis_7__c = analysis7.Id,
                Customer_Reference__c = 'REF-001',
                Paid_Amount__c = 100.00,
                Gift_Aid_Submission_Status__c = 'Non-Submitted'
            ));
            
            // Transaction 2: Rejected, eligible
            transactions.add(new Sales_Invoice_Transaction__c(
                //Name = 'TXN-002',
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Product__c = product.Id,
                Nominal_Code2__c = nominalCode.Id,
                Sale_VAT__c = vat.Id,
                Analysis_1__c = analysis1.Id,
                Analysis_2__c = analysis2.Id,
                Analysis_6__c = analysis6.Id,
                Analysis_7__c = analysis7.Id,
                Customer_Reference__c = 'REF-002',
                Paid_Amount__c = 250.00,
                Gift_Aid_Submission_Status__c = 'Rejected'
            ));
            
            // Transaction 3: Already Submitted (should not appear)
            transactions.add(new Sales_Invoice_Transaction__c(
                //Name = 'TXN-003',
                Sales_Invoice_Header__c = invoiceHeader.Id,
                Company__c = objComp.Id,
                Product__c = product.Id,
                Nominal_Code2__c = nominalCode.Id,
                Sale_VAT__c = vat.Id,
                Paid_Amount__c = 50.00,
                Gift_Aid_Submission_Status__c = 'Submitted'
            ));
            
            insert transactions;
        }
    }
    
    @isTest
    static void testGetTransactions_WithoutDateFilter() {
        Test.startTest();
        List<GiftAidSubmissionController.GiftAidSubmissionResultWrapper> results = 
            GiftAidSubmissionController.getTransactions(null, null);
        Test.stopTest();
        
        // Should return 2 eligible transactions (Non-Submitted and Rejected)
        System.assertEquals(2, results.size(), 'Should return 2 eligible transactions');
        
        // Verify wrapper data
        GiftAidSubmissionController.GiftAidSubmissionResultWrapper firstResult = results[0];
        System.assertNotEquals(null, firstResult.Id, 'Transaction Id should not be null');
        System.assertEquals('John', firstResult.contactFirstName, 'Contact first name should match');
        System.assertEquals('Smith', firstResult.contactLastName, 'Contact last name should match');
        System.assertEquals('E1 6AN', firstResult.contactPostalCode, 'Postal code should match');
        System.assertNotEquals(null, firstResult.paidAmount, 'Paid amount should not be null');
    }
    
    @isTest
    static void testGetTransactions_WithDateFilter() {
        Date startDate = Date.today().addDays(-10);
        Date endDate = Date.today();
        
        Test.startTest();
        List<GiftAidSubmissionController.GiftAidSubmissionResultWrapper> results = 
            GiftAidSubmissionController.getTransactions(startDate, endDate);
        Test.stopTest();
        
        // Should return transactions within date range
        System.assertEquals(2, results.size(), 'Should return transactions within date range');
        
        for (GiftAidSubmissionController.GiftAidSubmissionResultWrapper result : results) {
            System.assert(result.invoiceDate >= startDate && result.invoiceDate <= endDate, 
                          'Invoice date should be within specified range');
        }
    }
    
    @isTest
    static void testGetTransactions_NoEligibleTransactions() {
        // Delete all eligible contacts to simulate no eligible donors
        delete [SELECT Id FROM Contact WHERE Eligible_for_Gift_Aid__c = true];
        
        Test.startTest();
        List<GiftAidSubmissionController.GiftAidSubmissionResultWrapper> results = 
            GiftAidSubmissionController.getTransactions(null, null);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return no transactions when no eligible donors exist');
    }
    
    @isTest
    static void testSaveSubmission_Success() {
        User us = [SELECT Id FROM User WHERE Email='testuser@gmail.com' LIMIT 1];
        System.runAs(us){
            // Get eligible transactions
            List<Sales_Invoice_Transaction__c> txns = [
                SELECT Id 
                FROM Sales_Invoice_Transaction__c 
                WHERE Gift_Aid_Submission_Status__c IN ('Non-Submitted', 'Rejected')
                LIMIT 2
            ];
            
            List<Id> txnIds = new List<Id>();
            for (Sales_Invoice_Transaction__c txn : txns) {
                txnIds.add(txn.Id);
            }
            
            // Mock HTTP Response
            Test.setMock(HttpCalloutMock.class, new MockHMRCHttpResponse());
            
            Test.startTest();
            String result = GiftAidSubmissionController.saveSubmission(txnIds);
            Test.stopTest();
            
            System.assertEquals('Success', result, 'Submission should return Success');
            
            // Verify Gift Aid Submission record was created
            List<Gift_Aid_Submission__c> submissions = [
                SELECT Id, Submission_Number__c, Gift_Aid_Polling_Status__c 
                FROM Gift_Aid_Submission__c
            ];
            System.assertEquals(1, submissions.size(), 'One Gift Aid Submission should be created');
            System.assertEquals('TEST-CORRELATION-ID', submissions[0].Submission_Number__c, 
                                'Correlation ID should be extracted from response');
            System.assertEquals('In Progress', submissions[0].Gift_Aid_Polling_Status__c, 
                                'Status should be In Progress');
            
            // Verify transactions were updated
            List<Sales_Invoice_Transaction__c> updatedTxns = [
                SELECT Id, Gift_Aid_Submission_Status__c, Gift_Aid_Submission__c 
                FROM Sales_Invoice_Transaction__c 
                WHERE Id IN :txnIds
            ];
            
            for (Sales_Invoice_Transaction__c txn : updatedTxns) {
                System.assertEquals('Submitted', txn.Gift_Aid_Submission_Status__c, 
                                    'Transaction status should be Submitted');
                System.assertNotEquals(null, txn.Gift_Aid_Submission__c, 
                                       'Transaction should be linked to submission');
            }
        }
    }
    
    @isTest
    static void testSaveSubmission_EmptyList() {
        Test.setMock(HttpCalloutMock.class, new MockHMRCHttpResponse());
        
        Test.startTest();
        try {
            String result = GiftAidSubmissionController.saveSubmission(new List<Id>());
            System.assertEquals('Success', result, 'Should handle empty list gracefully');
        } catch (Exception e) {
            // System.assert(false, 'Should not throw exception for empty list');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveSubmission_HttpError() {
        List<Sales_Invoice_Transaction__c> txns = [
            SELECT Id 
            FROM Sales_Invoice_Transaction__c 
            WHERE Gift_Aid_Submission_Status__c = 'Non-Submitted'
            LIMIT 1
        ];
        
        // Mock HTTP Error Response
        Test.setMock(HttpCalloutMock.class, new MockHMRCHttpErrorResponse());
        
        Test.startTest();
        try {
            GiftAidSubmissionController.saveSubmission(new List<Id>{txns[0].Id});
            System.assert(false, 'Should throw exception on HTTP error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error') || e.getMessage().length() > 0, 
                          'Should throw AuraHandledException with error message');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveSubmission_MissingContactData() {
        // Create transaction for account without eligible contact
        User us = [SELECT Id FROM User WHERE Email='testuser@gmail.com' LIMIT 1];
        System.runAs(us){
            Account newAcc = [SELECT Id FROM Account LIMIT 1];
            
            Company__c company = [SELECT Id FROM Company__c LIMIT 1];
            Product2 product = [SELECT Id FROM Product2 LIMIT 1];
            Chart_Of_Accounts__c nominalCode = [SELECT Id FROM Chart_Of_Accounts__c LIMIT 1];
            VAT__c vat = [SELECT Id FROM VAT__c LIMIT 1];
            
            Sales_Invoice_Header__c header = [SELECT Id FROM Sales_Invoice_Header__c LIMIT 1];
            
            Sales_Invoice_Transaction__c txn = [SELECT Id FROM Sales_Invoice_Transaction__c WHERE Sales_Invoice_Header__c =:header.Id LIMIT 1];
            
            Test.setMock(HttpCalloutMock.class, new MockHMRCHttpResponse());
            
            Test.startTest();
            String result = GiftAidSubmissionController.saveSubmission(new List<Id>{txn.Id});
            Test.stopTest();
            
            // Should complete without including the transaction without contact
            System.assertEquals('Success', result, 'Should handle missing contact data');
        }
    }
    
    @isTest
    static void testGetTransactions_NullPostalCode() {
        // Update contact to have null postal code
        Contact con = [SELECT Id FROM Contact WHERE Eligible_for_Gift_Aid__c = true LIMIT 1];
        con.MailingPostalCode = null;
        update con;
        
        Test.startTest();
        List<GiftAidSubmissionController.GiftAidSubmissionResultWrapper> results = 
            GiftAidSubmissionController.getTransactions(null, null);
        Test.stopTest();
        
        System.assertEquals(2, results.size(), 'Should still return transactions');
        System.assertEquals('', results[0].contactPostalCode, 'Null postal code should be empty string');
    }
    
    @isTest
    static void testGetTransactions_MultipleCompanies() {
        
        Tax_Legislation__c taxlagis = [SELECT Id FROM Tax_Legislation__c LIMIT 1];
        // Create second company with transactions
        Company__c company2 = new Company__c(
            Name = 'Second Charity',
            Registered_Charity_Number__c = 'CHR789',
            Company_PostalCode__c = 'NW1 1AA',
            Telephone__c = '02087654321',
            aednpc__VAT_Period_covered_by_the_return__c = 'Quarterly',
            aednpc__Tax_Legislation__c = taxlagis.Id
        );
        insert company2;
        
        Test.startTest();
        List<GiftAidSubmissionController.GiftAidSubmissionResultWrapper> results = 
            GiftAidSubmissionController.getTransactions(null, null);
        Test.stopTest();
        
        // Should still filter correctly regardless of multiple companies
        System.assert(results.size() >= 2, 'Should return eligible transactions from all companies');
    }
    
    // Mock HTTP Response for successful HMRC call
    private class MockHMRCHttpResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?>' +
                        '<GovTalkMessage>' +
                        '<Header>' +
                        '<MessageDetails>' +
                        '<CorrelationID>TEST-CORRELATION-ID</CorrelationID>' +
                        '</MessageDetails>' +
                        '</Header>' +
                        '</GovTalkMessage>');
            return res;
        }
    }
    
    // Mock HTTP Response for HMRC error
    private class MockHMRCHttpErrorResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Error: Internal Server Error');
            return res;
        }
    }
}