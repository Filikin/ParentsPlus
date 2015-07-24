/*
Author: Eamon Kelly, Enclude
Purpose: Leads are inserted from a web to lead - from an order page
	Cart Contents will contain a JSON string with the line items for the order
	Attendees will contain a JSON string with the attendees for the campaign - but this will only be used then the order is activated and the campaign created
Called from: Convert button on the Lead
Test by:
	1) creating a lead with a product where the contact and the org do not exist
	2) creating a lead with a product where the contact and the org already exist
	3) creating a lead with a product and attendees 
*/
@isTest
public class TestLeadFromWeb 
{
	static Boolean runThisTest (integer testID)
	{
		integer testToRun = 0; // 0 means all tests
		if (testToRun == 0 || testToRun == testID) return true;
		else return false;
	}
	
	public static LeadFromWeb createController (Lead testL)
	{
   		ApexPages.StandardController lc = new ApexPAges.StandardController (testL);
    	LeadFromWeb lw = new LeadFromWeb (lc);
    	lw.LeadInsertedOrUpdated ();
    	return lw;
	}
	
    static testMethod void TestLeadWithNoLeadSource() 
    {
    	if (!runThisTest (1)) return;
    	
    	Lead testLead = new Lead (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', Company = 'Self', EMail = 'test@test123.com', Status='Open - not converted', Phone='08654323');
    	insert testLead;
    	createController (testLead);
     	
    	testLead = [select ID, Conversion_Error__c from Lead where ID=:testLead.id];
    	system.assertEquals ('LeadSource field not populated or not Web Order', testLead.Conversion_Error__c);
    }

    static testMethod void TestLeadWithNoContactsPresent() 
    {
    	if (!runThisTest (2)) return;

    	Lead testLead = new Lead (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', Company = 'Test Company', EMail = 'test@test123.com', Status='Open - not converted', Phone='08654323', LeadSource='Web Order', Street = 'Shipping');
    	insert testLead;
    	createController (testLead);

    	Contact newContact = [select FirstName, MobilePhone, MailingStreet, Account.Name, Account.BillingStreet from Contact where LastName = :testLead.LastName];
    	system.assertEquals (testLead.FirstName, newContact.FirstName);
    	system.assertEquals (testLead.Phone, newContact.MobilePhone);
    	system.assertEquals (testLead.Company, newContact.Account.Name);
    	system.assertEquals (testLead.Street, newContact.Account.BillingStreet);
    	system.assertEquals (testLead.Street, newContact.MailingStreet);
    }
    
    static testMethod void TestLeadWithContactPresent() 
    // contact and org should be updated with new details
    {
    	if (!runThisTest (3)) return;
		Account testOrg = new Account (Name='Test', ShippingStreet = 'Shipping');
		insert testOrg;
		
    	Contact testContact = new Contact (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', EMail = 'test@test123.com', Phone='12345', AccountID=testOrg.Id, MailingStreet='Some Street');
    	insert testContact;
    	Lead testLead = new Lead (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', Company = 'Test', State='Dublin', EMail = 'test@test123.com', Status='Open - not converted', Phone='8654323', LeadSource='Web Order', Street='New Street');
    	insert testLead;

    	createController (testLead);

    	Contact newContact = [select Phone, MailingStreet from Contact where Id = :testContact.id];
     	system.assertEquals (testLead.Phone, newContact.Phone);
     	system.assertEquals (testLead.Street, newContact.MailingStreet);
     	
     	Account newOrg = [select ID, BillingStreet from Account where ID = :testOrg.id];
     	system.assertEquals (testLead.Street, newOrg.BillingStreet);
     }
    
    static testMethod void TestLeadWithOrder ()
    {
    	if (!runThisTest (4)) return;
     	Product2 onsiteTraining = new Product2 (Name='Onsite', Family='Onsite Training', IsActive=true, ProductCode='85');
    	insert onsiteTraining;
    	
    	PricebookEntry onsiteTrainingPriceEntry = new PricebookEntry (Pricebook2ID=Test.getStandardPricebookId(), IsActive=true, Product2Id=onsiteTraining.id, UnitPrice=23.0); //, UseStandardPrice=false);
    	insert onsiteTrainingPriceEntry;
 
    	Lead testLead = new Lead (Salutation='Mr.', FirstName = 'Test', LastName = 'Testing123', Company = 'Self', EMail = 'test@test123.com', Status='Open - not converted', Phone='08654323', LeadSource='Web Order', Street='Some Street');
    	testLead.Cart_Contents__c = '[{"order_product_id":"528","order_id":"272","nid":"85","title":"Parenting When Separated [PARENT BOOKLETS - PACK OF 15]","manufacturer":"","model":"dfgdsf","qty":"1","cost":"0.00","price":"120.00","weight":"0","data":{"attributes":[],"shippable":"1","module":"uc_product"},"order_uid":"6"}]';
    	insert testLead;

    	createController (testLead);

    	Contact newContact = [select ID, Phone, MobilePhone from Contact where LastName = :testLead.LastName];
    	Order webOrder = [select Status, Type, BillingStreet from Order where CustomerAuthorizedById = :newContact.id];
    	system.assertEquals ('Draft', webOrder.Status);
    	system.assertEquals (testLead.Street, webOrder.BillingStreet);
    	
    	list<OrderItem> products = [select ID from OrderItem where OrderID=:webOrder.id];
    	system.assertEquals (1, products.size()); 
     }

}