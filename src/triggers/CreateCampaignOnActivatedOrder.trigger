/*
Author: Eamon Kelly, Enclude
Purpose: When an order is activated, for each onsite training in the order, create a campaign.
	•The name of the campaign is the org related to the order and the onsite product
	•The Host Org should be taken from the order
	•Link the order product to the campaign
Called from: Order activated
Tested in: Name of testing class
*/

trigger CreateCampaignOnActivatedOrder on Order (after update) 
{
	list <Campaign> campaignsToCreate = new list <Campaign> ();
	set <id> activatedOrders = new set <id> ();  
	for (Order oneOrder : trigger.new)
	{
		if (oneOrder.Status == 'Activated' && trigger.oldMap.get(oneOrder.id).Status != 'Activated')
		{
			activatedOrders.add (oneOrder.id);
		}
	}
	if (activatedOrders.size() > 0)
	{
		map <id, OrderItem> training = new map <id, OrderItem> ([select ID, Training_program__c, PricebookEntry.Product2.Name, Order.Account.Name from OrderItem where OrderId in :activatedOrders and PricebookEntry.Product2.Family = 'Onsite Training' and Training_program__c=null]);
		for (OrderItem oneTraining : training.values())
		{
			String OrgName = oneTraining.Order.Account.Name;
			String TrainingName = oneTraining.PricebookEntry.Product2.Name;
			Campaign oneCampaign = new Campaign (Name=OrgName + ' ' + TrainingName, Host_Organisation__c=oneTraining.Order.AccountId, IsActive=true);
			oneCampaign.Original_Order_Product__c = oneTraining.id; // temp pointer just to allow the orderitem to be saved for later
			campaignsToCreate.add (oneCampaign);
		}
		if (campaignsToCreate.size() > 0) insert campaignsToCreate;
		
		// now set training program in the orderitems
		for (Campaign oneCampaign : campaignsToCreate)
		{
			OrderItem oneTraining = training.get (oneCampaign.Original_Order_Product__c);
			oneTraining.Training_program__c = oneCampaign.id;
		} 
		update training.values();
	}
	
}