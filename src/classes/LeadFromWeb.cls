/*
Author: Eamon Kelly, Enclude
Purpose: Leads are inserted from a web to lead - from an order page
	Cart Contents will contain a JSON string with the line items for the order - this now includes single places in training courses
	
Called from: Convert button on the Lead
Tested in: TestLeadFromWeb
*/
public with sharing class LeadFromWeb 
{
	ID leadID;
	public LeadFromWeb (ApexPages.StandardController controller)
	{
		leadID = controller.getRecord().id;
	}

	public pageReference LeadInsertedOrUpdated ()
	{
		Lead ld = [select Id, leadSource, Status, Conversion_Error__c, Email, FirstName, LastName, Company, Street, City, State, Country, Profession__c, Phone,
				Purchase_Order_Number__c, Cart_Contents__c, Comments__c, Delivery_Area_Town__c, Delivery_City_County__c, 
				Delivery_Country__c, Delivery_Post_Code__c, Order_ID__c,
				Delivery_Street__c, Payment_Method__c from Lead where ID = :LeadID];

   		ld.Conversion_Error__c = '';
    	if (ld.leadsource == null || ld.leadsource != 'Web Order') 
    	{
    		ld.Conversion_Error__c = 'LeadSource field not populated or not Web Order'; 
    	}
		else
		{	    	
	    	if (isValid(ld.Email) && isValid(ld.LastName) && isValid(ld.Company) && ld.Status.contains('Open'))
	    	{
				Account contactsAccount=null;
				try
				{
					contactsAccount = [select id, Name from Account where Name = :ld.Company limit 1];
				}
				catch (Exception e)
				{ // assume account not found
					contactsAccount = new Account (Name=ld.Company);
				}
				// update the org details with the details from the web form
				if (isValid(ld.Street)) contactsAccount.BillingStreet = ld.Street;
	   			if (isValid(ld.City)) contactsAccount.BillingCity = ld.City;
	   			if (isValid(ld.State)) contactsAccount.BillingState = ld.State;
	   			if (isValid(ld.Country)) contactsAccount.BillingCountry = ld.Country;
	   			if (isValid(ld.Delivery_Street__c)) contactsAccount.ShippingStreet = ld.Delivery_Street__c;
	   			if (isValid(ld.Delivery_Area_Town__c)) contactsAccount.ShippingCity = ld.Delivery_Area_Town__c;
	   			if (isValid(ld.Delivery_City_County__c)) contactsAccount.ShippingState = ld.Delivery_City_County__c;
	   			if (isValid(ld.Delivery_Country__c)) contactsAccount.ShippingCountry = ld.Delivery_Country__c;
	   			
	   			upsert contactsAccount;
	   			
		
		   		Contact facilitator = null;
		   		Boolean newContact = false;
		 
		 		try
		 		{
		 			facilitator = [select id, FirstName, LastName, Phone, MobilePhone, Email, Title from Contact where email = :ld.Email and LastName = :ld.LastName limit 1];
		 		}
		 		catch (Exception e)
		 		{
		 			// assume contact not found 
			   		facilitator = new Contact (LastName = ld.LastName, Email = ld.Email);
			   		if (isValid(ld.Company)) facilitator.AccountID = contactsAccount.id;
			   		if (isValid(ld.FirstName)) facilitator.FirstName = ld.FirstName;
			   		newContact = true;
		   		}
		   		if (isValid (ld.Profession__c)) facilitator.Title = ld.Profession__c;
				if (isValid(ld.Street)) facilitator.MailingStreet = ld.Street;
		   		if (isValid(ld.City)) facilitator.MailingCity = ld.City;
		   		if (isValid(ld.State)) facilitator.MailingState = ld.State;
		   		if (isValid(ld.Country)) facilitator.MailingCountry = ld.Country;
		   			
			   	copyLandLineOrMobile (ld, facilitator);
	
				upsert facilitator;
			    		
				try
				{
					createOrder (ld, contactsAccount, facilitator);
		    	}
		    	catch (Exception e)
		    	{
		    		ld.Conversion_Error__c = e.GetMessage();
		    	}
	    	}
		    else if (ld.Status.contains('Open'))
		    {
		    	if (!isValid(ld.Email)) ld.Conversion_Error__c = 'Email address invalid ';
		    	if (!isValid(ld.LastName)) ld.Conversion_Error__c += ' Surname not valid';
		    	if (!isValid(ld.Company)) ld.Conversion_Error__c += ' Organisation name not valid';
	    	}
		}
		update ld;
		PageReference leadPage = new PageReference ('/' + ld.id);
		return leadPage;
    }
    
	public static boolean isValid (String text)
	{
		if (text <> null && text <> '' && text <> '[not provided]') return true;
		else return false;
	}
	
	
//	   	OrderItem op = new OrderItem (OrderId=testOrder.id, PricebookEntryID=onsiteTrainingPriceEntry.id, Quantity=1, UnitPrice=25);
//    	testLead.Cart_Contents__c = '[{"order_product_id":"528","order_id":"272","nid":"85","title":"Parenting When Separated [PARENT BOOKLETS - PACK OF 15]","manufacturer":"","model":"dfgdsf","qty":"1","cost":"0.00","price":"120.00","weight":"0","data":{"attributes":[],"shippable":"1","module":"uc_product"},"order_uid":"6"}]';
 // nid is the ProductCode in Salesforce, so need to match against product
 // if there are attendees, need to add them to the order in "Prog/supervision purchased for
	public boolean CreateOrderProducts (Lead ld, order webOrder, ID orgID)
	{
		try
		{
			list<OrderItem> items = new list<OrderItem>();
			list <Object> orderItems = (List<Object>)JSON.deserializeUntyped(ld.Cart_Contents__c);
			// first get the list of products
			set <String> productCodes = new set <String>();
			for (Object oneItem: orderItems)
			{
				Map<String, Object> workingItem = (Map<String, Object>)oneItem;
				String productCode = (String)workingItem.get ('nid');
				if (productCode != null) productCodes.add (productCode);
			}
			list<PricebookEntry> pre = [select ID, Product2.ProductCode, Product2.Training__c from PricebookEntry where Product2.ProductCode in :productCodes];
//			list<Product2> products = [select ID, ProductCode from Product2 where ProductCode in :productCodes];
			map <String, PricebookEntry> pricebookEntryMap = new map <String, PricebookEntry> ();
			for (PricebookEntry onePre: pre) pricebookEntryMap.put (onePre.Product2.ProductCode, onePre);
			
			for (Object oneItem: orderItems)
			{
				Map<String, Object> workingItem = (Map<String, Object>)oneItem;
				OrderItem newItem = new OrderItem (OrderID = webOrder.id);
				newItem.Quantity = Decimal.valueOf((String)workingItem.get('qty'));
				newItem.UnitPrice = Decimal.valueOf((String)workingItem.get('price'));
				PricebookEntry onePre = pricebookEntryMap.get((String)workingItem.get ('nid'));
				if (onePre != null)
				{
					newItem.PricebookEntryID = onePre.id;
					if (onePre.Product2.Training__c != null) newItem.Training_program__c = onePre.Product2.Training__c;
				}
				newItem.Purchased_for__c = AddWhoTheOrderWasPurchasedFor (workingItem, orgID, newItem);
				items.add (newItem);
			}
			insert items;
			return true;
		}
		catch (Exception e)
		{
			ld.Conversion_Error__c += 'Problem with order products list: ';
			ld.Conversion_Error__c += e.getMessage().left(1000);
		}
		return false;
	}
	
	// this is only going to work for up to 20 attendees, should be fine for Parents Plus
	public ID AddWhoTheOrderWasPurchasedFor (Map<String, Object> attendeeDetails, ID orgID, OrderItem newItem)
	{
		system.debug ('In AddWhoTheOrderWasPurchasedFor: ' + attendeeDetails);
		// skip if no lastName or email
		String contactName = (String)attendeeDetails.get ('first_name');
		if (contactName != null) contactName += ' ' + (String)attendeeDetails.get ('last_name');
		else contactName = (String)attendeeDetails.get ('last_name');
		String contactEmail = (String)attendeeDetails.get ('email');
					
		if (!isValid(contactName) || !isValid(contactEmail)) return null;
					
		Contact oneAttendee;
		try
		{
			oneAttendee = [select ID, FirstName, LastName from Contact where Name=:contactName and email=:contactEmail limit 1]; 
		}
		catch (Exception e)
		{
			String lastName = (String)attendeeDetails.get ('last_name');
			String firstName = (String)attendeeDetails.get ('first_name') == null ? '' : (String)attendeeDetails.get ('first_name');
			oneAttendee = new Contact (FirstName=firstName, LastName=lastName, AccountID=orgID, email=contactEmail);
			insert oneAttendee;
		}

		copyLandLineOrMobile ((String)attendeeDetails.get ('phone'), oneAttendee);
		if (isValid ((String)attendeeDetails.get('profession'))) oneAttendee.Title = (String)attendeeDetails.get('profession');
		if (isValid((String)attendeeDetails.get('street'))) oneAttendee.MailingStreet = (String)attendeeDetails.get('street');
		if (isValid((String)attendeeDetails.get('city'))) oneAttendee.MailingCity = (String)attendeeDetails.get('city');
		if (isValid((String)attendeeDetails.get('state'))) oneAttendee.MailingState = (String)attendeeDetails.get('state');
		if (isValid((String)attendeeDetails.get('country'))) oneAttendee.MailingCountry = (String)attendeeDetails.get('country');
		
		newItem.Description = oneAttendee.FirstName + ' ' + oneAttendee.LastName;
		newItem.Materials_Purchased__c = (Boolean)attendeeDetails.get('materials') == true;
		return oneAttendee.id;
	}
	
	public void createOrder (Lead ld, Account contactsAccount, Contact facilitator)
	{
		ID pricebookID;
		if (Test.isRunningTest()) pricebookID = Test.getStandardPricebookId(); 
		else pricebookID = [SELECT Id FROM Pricebook2 WHERE IsStandard = true].id;
   		order webOrder = new order (Type='Web', AccountID=contactsAccount.id, CustomerAuthorizedById=facilitator.id, Status='Draft',
   			EffectiveDate=system.today(), Pricebook2Id=pricebookID);
   		
   		if (isValid (ld.Purchase_Order_Number__c)) webOrder.Customer_order_number__c = ld.Purchase_Order_Number__c;
   		if (isValid (ld.Order_ID__c)) webOrder.Order_ID_from_web__c = ld.Order_ID__c; 

		// update the order details with the details from the web form
		if (isValid(ld.Street)) webOrder.BillingStreet = ld.Street;
		if (isValid(ld.City)) webOrder.BillingCity = ld.City;
		if (isValid(ld.State)) webOrder.BillingState = ld.State;
		if (isValid(ld.Country)) webOrder.BillingCountry = ld.Country;
		if (isValid(ld.Delivery_Street__c)) webOrder.ShippingStreet = ld.Delivery_Street__c;
		if (isValid(ld.Delivery_Area_Town__c)) webOrder.ShippingCity = ld.Delivery_Area_Town__c;
		if (isValid(ld.Delivery_City_County__c)) webOrder.ShippingState = ld.Delivery_City_County__c;
		if (isValid(ld.Delivery_Country__c)) webOrder.ShippingCountry = ld.Delivery_Country__c;
		webOrder.Lead_with_order__c = ld.id;
    		
		Savepoint sp = Database.setSavepoint();
    	insert webOrder;
		if (!CreateOrderProducts (ld, webOrder, contactsAccount.ID)) 
		{
			Database.rollback(sp);  // failed because of an error processing the line items
		}
	    else
	    {	
		    ld.Status = 'Closed - Converted';
		    ld.Conversion_Error__c = 'None';
	    }
	}

	public void copyLandLineOrMobile (String phoneNumber, Contact cont)
	{
		if (isValid (phoneNumber))
		{
			String phone = phoneNumber.deleteWhitespace();
			if (phone.startsWith('08') || phone.startsWith('003538') || phone.startsWith('+3538'))
				cont.MobilePhone = phone;
			else cont.Phone = phone;
		}
	}

	public void copyLandLineOrMobile (Lead ld, Contact cont)
	{
		if (isValid (ld.Phone))
		{
			String phone = ld.Phone.deleteWhitespace();
			if (phone.startsWith('08') || phone.startsWith('003538') || phone.startsWith('+3538'))
				cont.MobilePhone = phone;
			else cont.Phone = phone;
		}
	}
}