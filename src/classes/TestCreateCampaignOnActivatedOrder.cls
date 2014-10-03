/*
Author: Eamon Kelly, Enclude
Purpose: Test When an order is activated, for each onsite training in the order, create a campaign.
	•The name of the campaign is the org related to the order and the onsite product
	•The Host Org should be taken from the order
	•Link the order to the campaign (or the order product?)
*/
@isTest
private class TestCreateCampaignOnActivatedOrder 
{
    static testMethod void TestOrderActivated() 
    {
    	Account customer = new Account (Name='Test');
    	insert customer;
    	Order testOrder = new Order (AccountID=customer.id, EffectiveDate=system.today(), Status='Draft', Pricebook2Id=Test.getStandardPricebookId());
    	insert testOrder;
    	
    	Product2 onsiteTraining = new Product2 (Name='Onsite', Family='Onsite Training', IsActive=true);
    	insert onsiteTraining;
    	
    	PricebookEntry onsiteTrainingPriceEntry = new PricebookEntry (Pricebook2ID=Test.getStandardPricebookId(), IsActive=true, Product2Id=onsiteTraining.id, UnitPrice=23.0); //, UseStandardPrice=false);
    	insert onsiteTrainingPriceEntry;
    	
    	OrderItem op = new OrderItem (OrderId=testOrder.id, PricebookEntryID=onsiteTrainingPriceEntry.id, Quantity=1, UnitPrice=25);
    	insert op;
    	
    	testOrder.Status = 'Activated';
    	update testOrder;
    	
    	op = [select ID, Training_program__c from OrderItem where id=:op.id];
    	system.assert (op.Training_program__c != null);
    }
}