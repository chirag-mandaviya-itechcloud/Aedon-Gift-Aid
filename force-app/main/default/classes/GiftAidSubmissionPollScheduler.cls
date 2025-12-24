/**
 * GiftAidSubmissionPollScheduler
 *
 * Author: Abhishek D
 * Created Date: 2025-11-22
 * Last Modified By: Abhishek D
 * Last Modified Date: 2025-12-18
 *
 * Description:
 *  Scheduler to enqueue the GiftAidSubmissionPollBatch at scheduled intervals.
 */
public class GiftAidSubmissionPollScheduler implements Schedulable{
    /**
     * execute
     * Purpose: Entry point invoked by the Apex scheduler. Executes the GiftAidSubmissionPollBatch
     *          to poll HMRC for submission statuses. Batch size set to 50 to balance throughput and limits.
     * Params:
     *  - SchedulableContext SC: provided by the scheduler runtime.
     */
	public void execute(SchedulableContext SC) {
		Database.executeBatch(new GiftAidSubmissionPollBatch(), 50);
	}
}