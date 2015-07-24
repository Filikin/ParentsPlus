/*
	Author: Eamon Kelly, Enclude
	Purpose: Provide centralised access to the custom settings and make a copy available in test
	Copied from Advanced Apex Programming by Dan Appleman
*/
public with sharing class AppConfigSupport 
{
	private static parentsPlus__c testconfig = null;
	public static final Integer MAX_NAME_SIZE = 30;
	
	public static parentsPlus__c GetParentsPlusSettings()
	{
		if(Test.isRunningTest() && testconfig!=null) return testconfig;
		
		parentsPlus__c theobject = parentsPlus__c.getOrgDefaults();
		parentsPlus__c emptyObject = new parentsPlus__c ();
		if(theobject==null || theobject == emptyObject || Test.isRunningTest()) 
		{
			theobject = new parentsPlus__c();
			theobject.name = 'default';
			if(!Test.isRunningTest()) 
			{
				Database.Insert(theobject);
				theobject = parentsPlus__c.getOrgDefaults();
			}
			else // set default test values (can be different from default values) 
			{
				theobject.CreateCampaign__c = 'Onsite Training';
				theobject.Disable_Triggers__c = false;
				theobject.Supervisor_Training_Statuses__c = 'Sent,Responded';
				theobject.Onsite_Training_Statuses__c = 'Sent,Responded';
				testconfig = theobject;
			}
		}
		return theobject;
	}
	
	public static String CreateCampaignProductType
	{
		get
		{
			return GetParentsPlusSettings().CreateCampaign__c;
		}
	}

	public static Boolean TriggersDisabled
	{
		get
		{
			return GetParentsPlusSettings().Disable_Triggers__c;
		}
	}
	
	public static list<String> SupervisorTrainingStatuses
	{
		get
		{
			return GetParentsPlusSettings().Supervisor_Training_Statuses__c.split(',');
		}
	}
	
	public static list<String> OnsiteTrainingStatuses
	{
		get
		{
			return GetParentsPlusSettings().Onsite_Training_Statuses__c.split(',');
		}
	}
	
}