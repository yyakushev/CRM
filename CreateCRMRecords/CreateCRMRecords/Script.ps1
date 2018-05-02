#
# Script.ps1
#
param (
	[string] $filepath = '.\CRM_time_yyakushev_2017_new.csv'
)

#Github module can be downloaded here https://github.com/seanmcne/Microsoft.Xrm.Data.PowerShell
Import-Module Microsoft.Xrm.Data.Powershell
$cred = Get-Credential
Connect-CrmOnline -Credential $cred -ServerUrl 'https://itvt.crm4.dynamics.com'

#Get data for CRM import from csv file
$DataForCRM = Import-Csv $filepath

#Define value for the closed task state
$closed = '1'
#Entity name for the task
$EntLogName_Task = 'task'
#Entity name for the project
$EntLogName_project = 'msdyn_project'

#Get list of all projects in CRM
$projects = Get-CrmRecords -EntityLogicalName $EntLogName_project -Fields msdyn_subject,msdyn_projectid
#$projects.CrmRecords | ? {$_.msdyn_subject -like "itvt - data*"}

#Get list of all users
$CRMUsers = Get-CrmRecords -EntityLogicalName systemuser  -Fields systemuserid,fullname,domainname


foreach ($record in $DataForCRM) {
	
	$OwnerID = ($CRMUsers.CrmRecords | ? fullname -like $record.Owner).systemuserid

	$duration = [int] $record.Duration
	$time = [datetime] $record.DueDate
	$subject = $record.Subject

	$porjectID = ($projects.CrmRecords | ? {$_.msdyn_subject -eq $record.Regarding})[0].msdyn_projectid

	#Create new CRM record
	$NewCRMRecord = New-CrmRecord -EntityLogicalName $EntLogName_Task @{"owneridyominame"=$OwnerID;`
		'regardingobjectid'= New-CrmEntityReference -Id $porjectID.Guid -EntityLogicalName $EntLogName_project;`
		"subject"=$subject;`
		"actualdurationminutes"=$duration;`
		"scheduledend"=$time}

	#Close CRM record
	Set-CrmRecord -EntityLogicalName task `
		-Id $NewCRMRecord.Guid`
		-Fields @{'statecode'=New-CrmOptionSetValue -Value $closed}
}
			