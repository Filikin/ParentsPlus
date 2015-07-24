/*
Author: Eamon Kelly, Enclude
Purpose: When an order is activated, for each onsite training in the order, create a campaign.
	?The name of the campaign is the org related to the order and the onsite product
	?The Host Org should be taken from the order
	?Link the order product to the campaign
Called from: Order activated
Tested in: Name of testing class
*/

trigger CreateCampaignOnActivatedOrder on Order (after update) 
{
		TriggerDispatcher.MainEntry ('Order', trigger.isBefore, trigger.isDelete, trigger.isAfter, trigger.isInsert, trigger.isUpdate, trigger.isExecuting,
		trigger.new, trigger.newMap, trigger.old, trigger.oldMap);
}