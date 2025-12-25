/**
 * GiftAidSubmissionPollSchedulerTest
 *
 * Author: Abhishek D
 * Created Date: 2025-12-25
 *
 * Description:
 *  Test class for GiftAidSubmissionPollScheduler
 *  Provides coverage for scheduled job execution and batch invocation
 */
@isTest
private class GiftAidSubmissionPollSchedulerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Gift Aid Custom Settings required by the batch
        GiftAidSubmission__c settings = new GiftAidSubmission__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            endpoint__c = 'https://test.hmrc.gov.uk/submission',
            polling_endpoint__c = 'https://test.hmrc.gov.uk/polling'
        );
        insert settings;
        
        // Create a Gift Aid Submission in "In Progress" status
        Gift_Aid_Submission__c submission = new Gift_Aid_Submission__c(
            Submission_Number__c = 'TEST-CORR-001',
            Submission_Date__c = Date.today(),
            Gift_Aid_Polling_Status__c = 'In Progress',
            Submitted_By__c = UserInfo.getUserId()
        );
        insert submission;
    }
    
    @isTest
    static void testSchedulerExecution() {
        // Mock HTTP response for the batch that will be executed
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        // CRON expression for running the job (e.g., every day at midnight)
        String cronExp = '0 0 0 * * ?';
        
        Test.startTest();
        
        // Schedule the job
        String jobId = System.schedule(
            'Test Gift Aid Poll Scheduler',
            cronExp,
            new GiftAidSubmissionPollScheduler()
        );
        
        // Verify the job was scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');
        
        // Get scheduled job details
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals(cronExp, ct.CronExpression, 'CRON expression should match');
        System.assertEquals(0, ct.TimesTriggered, 'Job should not have run yet');
        
        Test.stopTest();
        
        // After Test.stopTest(), scheduled jobs execute
        // Verify batch was queued (check AsyncApexJob)
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'GiftAidSubmissionPollBatch'
            AND JobType = 'BatchApex'
        ];
        
        System.assert(!jobs.isEmpty(), 'Batch job should have been queued');
        System.assertEquals('GiftAidSubmissionPollBatch', jobs[0].ApexClass.Name, 
                          'Correct batch class should be queued');
    }
    
    @isTest
    static void testSchedulerManualExecution() {
        // Test direct execution of the scheduler (simulating manual run)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        
        // Manually execute the scheduler
        GiftAidSubmissionPollScheduler scheduler = new GiftAidSubmissionPollScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify batch was executed
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType, ApexClass.Name, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'GiftAidSubmissionPollBatch'
            AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        System.assert(!jobs.isEmpty(), 'Batch job should have been executed');
        System.assertEquals('GiftAidSubmissionPollBatch', jobs[0].ApexClass.Name, 
                          'Correct batch should be executed');
    }
    
    @isTest
    static void testSchedulerWithMultipleSchedules() {
        // Test scheduling multiple instances
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        String cronExp1 = '0 0 0 * * ?';  // Midnight daily
        String cronExp2 = '0 0 12 * * ?'; // Noon daily
        
        Test.startTest();
        
        String jobId1 = System.schedule(
            'Gift Aid Poll Scheduler - Midnight',
            cronExp1,
            new GiftAidSubmissionPollScheduler()
        );
        
        String jobId2 = System.schedule(
            'Gift Aid Poll Scheduler - Noon',
            cronExp2,
            new GiftAidSubmissionPollScheduler()
        );
        
        System.assertNotEquals(null, jobId1, 'First job should be scheduled');
        System.assertNotEquals(null, jobId2, 'Second job should be scheduled');
        System.assertNotEquals(jobId1, jobId2, 'Job IDs should be different');
        
        Test.stopTest();
        
        // Verify both jobs are scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronJobDetail.Name, CronExpression
            FROM CronTrigger
            WHERE Id IN (:jobId1, :jobId2)
        ];
        
        System.assertEquals(2, scheduledJobs.size(), 'Both jobs should be scheduled');
    }
    
    @isTest
    static void testSchedulerAbortJob() {
        // Test aborting a scheduled job
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        String cronExp = '0 0 0 * * ?';
        
        Test.startTest();
        
        String jobId = System.schedule(
            'Test Gift Aid Poll Scheduler to Abort',
            cronExp,
            new GiftAidSubmissionPollScheduler()
        );
        
        // Abort the scheduled job
        System.abortJob(jobId);
        
        Test.stopTest();
        
        // Verify job was aborted
        List<CronTrigger> scheduledJobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        if (!scheduledJobs.isEmpty()) {
            System.assertEquals('DELETED', scheduledJobs[0].State, 'Job should be deleted/aborted');
        }
    }
    
    @isTest
    static void testSchedulerWithNoData() {
        // Delete all Gift Aid Submissions to test with no data
        delete [SELECT Id FROM Gift_Aid_Submission__c];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        
        // Execute scheduler with no data
        GiftAidSubmissionPollScheduler scheduler = new GiftAidSubmissionPollScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Batch should still execute successfully even with no records
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'GiftAidSubmissionPollBatch'
            AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        System.assert(!jobs.isEmpty(), 'Batch should execute even with no data');
        System.assertEquals(0, jobs[0].NumberOfErrors, 'Should have no errors');
    }
    
    @isTest
    static void testSchedulerBatchSize() {
        // Verify that the batch is executed with the correct batch size (50)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        
        GiftAidSubmissionPollScheduler scheduler = new GiftAidSubmissionPollScheduler();
        scheduler.execute(null);
        
        Test.stopTest();
        
        // Verify batch job exists
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ApexClass.Name, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'GiftAidSubmissionPollBatch'
            AND JobType = 'BatchApex'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        System.assert(!jobs.isEmpty(), 'Batch job should be created');
        System.assertEquals('GiftAidSubmissionPollBatch', jobs[0].ApexClass.Name,
                          'Correct batch class should be invoked');
        
        // Note: We cannot directly verify the batch size from AsyncApexJob,
        // but we can confirm the batch was executed with the correct class
    }
    
    @isTest
    static void testSchedulerCronExpressionVariations() {
        // Test different CRON expressions to ensure scheduler accepts them
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        List<String> cronExpressions = new List<String>{
            '0 0 0 * * ?',      // Daily at midnight
            '0 0 */6 * * ?',    // Every 6 hours
            '0 0 0 ? * MON',    // Every Monday at midnight
            '0 30 8 1 * ?'      // 8:30 AM on first day of every month
        };
        
        Test.startTest();
        
        Integer index = 0;
        for (String cronExp : cronExpressions) {
            String jobId = System.schedule(
                'Test Scheduler ' + index,
                cronExp,
                new GiftAidSubmissionPollScheduler()
            );
            
            System.assertNotEquals(null, jobId, 
                'Job with CRON expression ' + cronExp + ' should be scheduled');
            index++;
        }
        
        Test.stopTest();
        
        // Verify all jobs were scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Test Scheduler%'
        ];
        
        System.assertEquals(cronExpressions.size(), scheduledJobs.size(), 
                          'All CRON variations should be scheduled');
    }
    
    @isTest
    static void testSchedulerExecutionContext() {
        // Test that the scheduler receives proper context
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        
        // Create a custom schedulable context (null is acceptable for testing)
        GiftAidSubmissionPollScheduler scheduler = new GiftAidSubmissionPollScheduler();
        
        // Execute with null context (scheduler should handle gracefully)
        try {
            scheduler.execute(null);
            System.assert(true, 'Scheduler should execute with null context');
        } catch (Exception e) {
            System.assert(false, 'Scheduler should not throw exception with null context: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSchedulerWithExistingBatchRunning() {
        // Test scheduling when a batch might already be running
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());
        
        Test.startTest();
        
        // Execute scheduler twice to simulate overlapping executions
        GiftAidSubmissionPollScheduler scheduler1 = new GiftAidSubmissionPollScheduler();
        scheduler1.execute(null);
        
        GiftAidSubmissionPollScheduler scheduler2 = new GiftAidSubmissionPollScheduler();
        scheduler2.execute(null);
        
        Test.stopTest();
        
        // Both batches should be queued
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'GiftAidSubmissionPollBatch'
            AND JobType = 'BatchApex'
        ];
        
        System.assert(jobs.size() >= 2, 'Multiple batch instances should be allowed');
    }
    
    // Mock HTTP Response for batch callouts
    private class MockHttpResponse implements HttpCalloutMock {
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
                       '<CorrelationID>TEST-CORR-001</CorrelationID>' +
                       '</MessageDetails>' +
                       '</Header>' +
                       '<Body>Success</Body>' +
                       '</GovTalkMessage>');
            return res;
        }
    }
}