public class GiftAidSubmissionPollScheduler implements Schedulable{
	public void execute(SchedulableContext SC) {
		Database.executeBatch(new GiftAidSubmissionPollBatch(), 50);
	}
}