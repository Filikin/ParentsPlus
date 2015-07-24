/*
Author: Eamon Kelly, Enclude
Purpose: Test When an order is activated, for each onsite training in the order, create a campaign.
	?The name of the campaign is the org related to the order and the onsite product
	?The Host Org should be taken from the order
	?Link the order to the campaign (or the order product?)
*/
@isTest
private class TestCreateCampaignOnActivatedOrder 
{
    static testMethod void TestOrderActivated() 
    {
    	Account customer = new Account (Name='Test');
    	insert customer;
    	Order testOrder = new Order (AccountID=customer.id, EffectiveDate=system.today(), Status='Draft', Pricebook2Id=Test.getStandardPricebookId());
    	testOrder.Attendees__c = '[{"email":"attendee1@gmail.com","phone":"Attendee 1 Telephone","company":"Attendee 1 Organisation","profession":"Attendee 1 Profession","name":"Attendee 1","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"18 Ryebridge Avenue"},{"email":"attendee2@gmail.com","phone":"Attendee 2 Telephone","company":"Attendee 2 Organisation","profession":"Attendee 2 Profession","name":"Attendee 2","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"19 Ryebridge Avenue"},{"email":"attendee3@gmail.com","phone":"Attendee 3 Telephone","company":"Attendee 3 Organisation","profession":"Attendee 3 Profession","name":"Attendee 3","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"16 Ryebridge Avenue"}]';
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

    static testMethod void TestOrderActivatedForIndividual() 
    {
    	Account customer = new Account (Name='Test');
    	insert customer;
    	
    	Contact supervisor = new Contact (LastName='Super', AccountID=customer.id);
    	insert supervisor;
    	
    	Order testOrder = new Order (AccountID=customer.id, EffectiveDate=system.today(), Status='Draft', Pricebook2Id=Test.getStandardPricebookId());
    	insert testOrder;
    	
    	Product2 onsiteTraining = new Product2 (Name='Individual Review', Family='Individual', IsActive=true);
    	insert onsiteTraining;
    	
    	PricebookEntry onsiteTrainingPriceEntry = new PricebookEntry (Pricebook2ID=Test.getStandardPricebookId(), IsActive=true, Product2Id=onsiteTraining.id, UnitPrice=23.0); 
    	insert onsiteTrainingPriceEntry;
    	
    	OrderItem op = new OrderItem (OrderId=testOrder.id, PricebookEntryID=onsiteTrainingPriceEntry.id, Quantity=1, UnitPrice=25, Purchased_for__c=supervisor.id);
    	insert op;
    	
    	testOrder.Status = 'Activated';
    	update testOrder;
    	
    	op = [select ID, Training_program__c from OrderItem where id=:op.id];
    	system.assert (op.Training_program__c != null);
    	
    	CampaignMember cm = [select ContactID from CampaignMember where CampaignID=:op.Training_program__c limit 1];
    	system.assertEquals (supervisor.id, cm.ContactID);
    }
    
    static testMethod void TestOrderActivatedForScheduledTraining() 
    {
     	Campaign training = new Campaign (Name='Training', Type='Training - Scheduled', IsActive=true);
    	insert training; 
    	
    	Product2 scheduledTraining = new Product2 (Name='Scheduled', Family='Scheduled Training', IsActive=true, Training__c = training.id, ProductCode='85');
    	insert scheduledTraining;
    	
    	PricebookEntry scheduledTrainingPriceEntry = new PricebookEntry (Pricebook2ID=Test.getStandardPricebookId(), IsActive=true, Product2Id=scheduledTraining.id, UnitPrice=23.0); //, UseStandardPrice=false);
    	insert scheduledTrainingPriceEntry;
   	
    	Lead testLead = new Lead (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', Company = 'Self', EMail = 'test@test123.com', Status='Open - not converted', Phone='08654323', LeadSource='Web Order', Street='Some Street');
    	testLead.Cart_Contents__c = '[{"order_product_id":"528","order_id":"272","nid":"85","title":"Parenting When Separated Scheduled Training","manufacturer":"","model":"dfgdsf","qty":"1","cost":"0.00","price":"120.00","weight":"0","data":{"attributes":[],"shippable":"1","module":"uc_product"},"order_uid":"6"}]';
    	testLead.Attendees__c = '[{"email":"attendee1@gmail.com","phone":"Attendee 1 Telephone","company":"Attendee 1 Organisation","profession":"Attendee 1 Profession","name":"Attendee 1","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"18 Ryebridge Avenue"},{"email":"attendee2@gmail.com","phone":"Attendee 2 Telephone","company":"Attendee 2 Organisation","profession":"Attendee 2 Profession","name":"Attendee 2","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"19 Ryebridge Avenue"},{"email":"attendee3@gmail.com","phone":"Attendee 3 Telephone","company":"Attendee 3 Organisation","profession":"Attendee 3 Profession","name":"Attendee 3","country":" Ireland","state":" Co. Kildare","city":" Kilcock","street":"16 Ryebridge Avenue"}]';
    	insert testLead;

    	TestLeadFromWeb.createController (testLead);

    	Contact newContact = [select ID, Phone, MobilePhone from Contact where LastName = :testLead.LastName];
    	Order webOrder = [select Status, Type, BillingStreet from Order where CustomerAuthorizedById = :newContact.id];
    	system.assertEquals ('Draft', webOrder.Status);
    	system.assertEquals (testLead.Street, webOrder.BillingStreet);
    	
    	list<OrderItem> products = [select ID from OrderItem where OrderID=:webOrder.id];
    	system.assertEquals (1, products.size()); 

    	webOrder.Status = 'Activated';
    	update webOrder;
    	
    	OrderItem oi = [select ID, Training_program__c from OrderItem where id=:products[0].id];
    	system.assertEquals (training.id, oi.Training_program__c);
    	
    	list<CampaignMember> attendees = [select Id from CampaignMember where CampaignID = :training.id];
    	system.assertEquals (3, attendees.size());
    }
    
}