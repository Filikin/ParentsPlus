/*
	Author: Eamon Kelly, Enclude
	Purpose: Dispatcher for triggers 
	Called from: Triggers
	Test notes: This class is tested in testCarePlanEventTrigger 
*/
public class TriggerDispatcher 
{
	public static Boolean InTrigger = false;
	
	public interface ITriggerEntry 
	{
		void MainEntry (String TriggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting,
			List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap);
	}
	
	public static ITriggerEntry activeFunction = null;
	
	public static void MainEntry (String TriggerObject, Boolean isBefore, Boolean isDelete, Boolean isAfter, Boolean isInsert, Boolean isUpdate, Boolean isExecuting,
		List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap)
	{
		if (AppConfigSupport.TriggersDisabled == true) return;
		
		if (TriggerObject == 'Order')
		{
			InTrigger = true;
			activeFunction = new OrderTriggerClass();
			activeFunction.MainEntry (TriggerObject, isBefore, isDelete, isAfter, isInsert, isUpdate, isExecuting, newList, newMap, oldList, oldMap);
			InTrigger = false;
		}
	}
}