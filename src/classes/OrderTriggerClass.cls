/*
Author: Eamon Kelly, Enclude
Purpose: When an order is activated, for each onsite training in the order, create a campaign.
	?The name of the campaign is the org related to the order and the onsite product
	?The Host Org should be taken from the order
	?Link the order product to the campaign
	
	For each individual training, if the Supervision field is populated, create a campaign and link the contact to it as a member
	?The name of the campaign is the org related to the order and the onsite product
	?The Host Org should be taken from the order
	?Link the order product to the campaign
	
	Only scheduled training courses can be booked online
	When a course is arranged, the product for that course is linked to a campaign.
	When a place on a course is ordered, the order item is linked to the campaign - this is all done in the LeadFromWeb class
	When the order is activated, the attendees are created as contacts if they are not already in Salesforce and added to the campaign
	
Called from: Order activated
Tested in: TestCreateCampaignOnActivatedOrder
*/
public with sharing class OrderTriggerClass implements TriggerDispatcher.ITriggerEntry
{
	list <Campaign> campaignsToCreate = new list <Campaign> ();
	set <id> activatedOrders = new set <id> ();  
	
	public void MainEntry (String TriggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting,
		List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap)
	{
		if (isUpdate && isAfter) OrderActivated (newList, (map<Id, Order>) oldMap);
	}
		
	public void OrderActivated (list<Order> newList, map<Id, Order> oldMap)
	{
		for (Order oneOrder : newList)
		{
			if (oneOrder.Status == 'Activated' && oldMap.get(oneOrder.id).Status != 'Activated')
			{
				activatedOrders.add (oneOrder.id);
			}
		}
		if (activatedOrders.size() > 0)
		{
			CreateTrainingCoursesForOnSiteAndIndividualTraining (activatedOrders);
			AddAttendeesToScheduledTraining (activatedOrders);
		}
	}	

	public void AddAttendeesToScheduledTraining (set <id> ordersSet)
	{
		map <id, OrderItem> training = new map <id, OrderItem> ([select ID, Training_program__c, PricebookEntry.Product2.Name, Order.Account.Name, Order.AccountID, Order.Attendees__c, PricebookEntry.Product2.Family, Purchased_for__c 
			from OrderItem where OrderId in :ordersSet and
			 PricebookEntry.Product2.Family = 'Scheduled Training' and Training_program__c != null]);
		
		for (OrderItem oneTraining : training.values())
		{
			addAttendeesToCampaign (oneTraining.Training_program__c, oneTraining.Order.Attendees__c, oneTraining.Order.AccountID);
		} 
		update training.values();
	}

	public void CreateTrainingCoursesForOnSiteAndIndividualTraining (set <id> ordersSet)
	{
		map <id, OrderItem> training = new map <id, OrderItem> ([select ID, Training_program__c, PricebookEntry.Product2.Name, Order.Account.Name, Order.AccountID, Order.Attendees__c, PricebookEntry.Product2.Family, Purchased_for__c 
			from OrderItem where OrderId in :ordersSet and
			 (PricebookEntry.Product2.Family = 'Onsite Training' or (PricebookEntry.Product2.Family = 'Individual' and Purchased_for__c != null)) 
			 and Training_program__c=null]);
		for (OrderItem oneTraining : training.values())
		{
			String OrgName = oneTraining.Order.Account.Name;
			String TrainingName = oneTraining.PricebookEntry.Product2.Name;
			String campName = OrgName + ' ' + TrainingName;
			if (campName.length() > 80) campName = campName.subString (0, 79);
			Campaign oneCampaign = new Campaign (Name=campName, Host_Organisation__c=oneTraining.Order.AccountId, IsActive=true);
			oneCampaign.Original_Order_Product__c = oneTraining.id; // temp pointer just to allow the orderitem to be saved for later
			if (oneTraining.PricebookEntry.Product2.Family == 'Onsite Training') oneCampaign.Type = 'Training - Onsite';
			else oneCampaign.Type = 'Supervision - Individual';
			campaignsToCreate.add (oneCampaign);
		}
		if (campaignsToCreate.size() > 0) insert campaignsToCreate;
		
		// now set training program in the orderitems and add the supervisor if required
		list <CampaignMember> supervisors = new list<CampaignMember>();
		for (Campaign oneCampaign : campaignsToCreate)
		{
			OrderItem oneTraining = training.get (oneCampaign.Original_Order_Product__c);
			oneTraining.Training_program__c = oneCampaign.id;
			
			if (oneCampaign.Type == 'Supervision - Individual')
			{
				copyCampaignMemberStatus (oneCampaign.id, AppConfigSupport.SupervisorTrainingStatuses);
				CampaignMember cm = new CampaignMember (ContactID=oneTraining.Purchased_for__c, CampaignID=oneCampaign.id);
				supervisors.add (cm);
			}
			else if (oneCampaign.Type == 'Training - Onsite')
			{
				copyCampaignMemberStatus (oneCampaign.id, AppConfigSupport.OnsiteTrainingStatuses);
			}
		} 
		update training.values();
		if (supervisors.size() > 0) insert supervisors;
	}
	
	public void copyCampaignMemberStatus (ID clonedCampaign, list<String> statusValues)
	{
       	delete [SELECT Id FROM CampaignMemberStatus where CampaignId = :clonedCampaign and isDefault = false];
       	Integer SortOrder=0;
		for (String oneStatus: statusValues)
 		{
 			CampaignMemberStatus newStatus = new CampaignMemberStatus (Label=oneStatus);
 			newStatus.CampaignId = clonedCampaign;
 			newStatus.isDefault = SortOrder == 0;
 			newStatus.SortOrder = SortOrder+=5;
  			try
 			{
 				insert newStatus;
 			}
 			catch (Exception e)
 			{
 				system.debug ('Failed to add CampaignMemberStatus ' + e);
  			}
 		}
	}
	
	public class orderException extends Exception {}
	
	// this will only work if name and email are provided for the attendees
	public void addAttendeesToCampaign (ID trainingID, String attendeesAsJSON, ID orgID)
	{
		if (attendeesAsJSON != null && attendeesAsJSON.length() > 0)
		{
			try
			{
				list<Contact> contactsToUpdate = new list<Contact>();
				list<CampaignMember> newTrainingAttendees = new list <CampaignMember>();
				list <Object> attendeeItems = (List<Object>)JSON.deserializeUntyped(attendeesAsJSON);
	
	// this is only going to work for up to 20 attendees, should be fine for Parents Plus
				for (Object oneItem: attendeeItems)
				{
					// skip if no lastName or email
					Map<String, Object> workingItem = (Map<String, Object>)oneItem;
					String contactName = (String)workingItem.get ('name');
					String contactEmail = (String)workingItem.get ('email');
					
					if (!isValid(contactName) || !isValid(contactEmail)) continue;
					
					Contact oneAttendee;
					try
					{
						oneAttendee = [select ID from Contact where Name=:contactName and email=:contactEmail limit 1]; 
					}
					catch (Exception e)
					{
						String lastName = contactName;
						String firstName = '';
						list<String> names = contactName.split (' ', 2);
						if (names.size() > 1)
						{
							lastName = names[1];
							firstName = names[0]; 
						} 
						oneAttendee = new Contact (FirstName=firstName, LastName=lastName, AccountID=orgID, email=contactEmail);
						insert oneAttendee;
					}
					
					copyLandLineOrMobile ((String)workingItem.get ('phone'), oneAttendee);
					if (isValid ((String)workingItem.get('profession'))) oneAttendee.Title = (String)workingItem.get('profession');
					if (isValid((String)workingItem.get('street'))) oneAttendee.MailingStreet = (String)workingItem.get('street');
					if (isValid((String)workingItem.get('city'))) oneAttendee.MailingCity = (String)workingItem.get('city');
					if (isValid((String)workingItem.get('state'))) oneAttendee.MailingState = (String)workingItem.get('state');
					if (isValid((String)workingItem.get('country'))) oneAttendee.MailingCountry = (String)workingItem.get('country');
					
					contactsToUpdate.add (oneAttendee);
	
					CampaignMember newCM = new CampaignMember (CampaignID = trainingId, ContactID=oneAttendee.id);
					newTrainingAttendees.add (newCM);
				}
				if (newTrainingAttendees.size() > 0) insert newTrainingAttendees;
				if (contactsToUpdate.size() > 0) update contactsToUpdate;
			}
			catch (Exception e)
			{
				throw new orderException ('Problem with attendees list: ' + e.getMessage().left(1000));
			}
		}		
	}
	
	public static boolean isValid (String text)
	{
		if (text <> null && text <> '' && text <> '[not provided]') return true;
		else return false;
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
	
}