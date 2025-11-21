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
}
