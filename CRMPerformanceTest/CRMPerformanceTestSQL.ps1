#
# CRMPerformanceTestSQL.ps1
#
# 
[cmdletbinding(SupportsShouldProcess=$True)]

Param (
	[Parameter(Mandatory = $true)]
	[ValidateScript({$_ -match "([\w-]+).crm([0-9]*).dynamics.com"})]
	[string] $Dyn365Url,

#	[PSCredential]$Dyn365Credentials = (Get-Credential -Message 'Please provide credentials for Dynamics 365'),

	[ValidateScript({Test-Path $_ -PathType Leaf})]
	[string] $LogPath  = $PWD,

	[Parameter(Mandatory=$true)][string] $SQLServerName,
	[Parameter(Mandatory=$true)][string] $DatabaseName,
	[Parameter(Mandatory=$true)][string] $TableName,

	[Parameter(Mandatory=$false,ParameterSetName="sqlauthentication")][string] $sqlusername,
	[Parameter(Mandatory=$false,ParameterSetName="sqlauthentication")][string] $sqluserpassword,
	[Parameter(Mandatory=$true,ParameterSetName="windowsauthentication")][switch] $usewindowsauthentication = $True

)

$formatdate = get-date -Format "HH.mm.ss_dd.MM.yyyy"
$LogName = "$($formatdate)_CRMPerformanceTest.log"
$script:ErrorActionPreference = "Stop"
$Log = "$LogPath\$LogName"

#function writes events to event log and shows information messages on console
function Write-ErrorEventLog ([string] $msg, [string] $Log) {
	$t = $host.ui.RawUI.ForegroundColor
	$host.ui.RawUI.ForegroundColor = "Red"
	Write-Output $msg
	$host.ui.RawUI.ForegroundColor = $t
	try {
		if  (Test-Path -Path $logpath -ErrorAction SilentlyContinue ) {
			"$(get-date -Format "HH:mm:ss dd-MM-yyyy: ")$msg" | Out-File -FilePath $Log -Append
		}
	} catch {
		"$(get-date -Format "HH:mm:ss dd-MM-yyyy: ") cannot find the log file to write the following message: $msg." | Out-File -FilePath error.log -Append
	}
}

#function writes events to event log and shows error messages on console
function Write-InformationEventLog ([string] $msg, [string] $Log) {
	$t = $host.ui.RawUI.ForegroundColor
	$host.ui.RawUI.ForegroundColor = "Yellow"
	Write-Output $msg
	$host.ui.RawUI.ForegroundColor = $t
	try {
		if  (Test-Path -Path $logpath -ErrorAction SilentlyContinue ) {
			"$(get-date -Format "HH:mm:ss dd-MM-yyyy: ")$msg" | Out-File -FilePath $Log -Append
		}
	} catch {
		"$(get-date -Format "HH:mm:ss dd-MM-yyyy: ") cannot find the log file to write the following message: $msg." | Out-File -FilePath error.log -Append
	}
}

<#
#Github module can be downloaded here https://github.com/seanmcne/Microsoft.Xrm.Data.PowerShell
if (Get-Module -Name Microsoft.Xrm.Data.Powershell -ListAvailable) {
	import-module Microsoft.Xrm.Data.Powershell
	Write-InformationEventLog -msg "Microsoft.Xrm.Data.Powershell module has been successfully loaded" -Log $Log
} else {
	Write-ErrorEventLog -msg "Microsoft.Xrm.Data.Powershell module has not been found. Please download and install it from here https://github.com/seanmcne/Microsoft.Xrm.Data.PowerShell" -Log $Log
	exit
}

#Connect to Dynamics 365 and test if connection is successful

try {
	$Dyn365Connection = Connect-CrmOnline -Credential $Dyn365Credentials -ServerUrl $Dyn365Url
}catch{
	Write-ErrorEventLog -msg "Cannoct connect to CRM online. Please find more information here:`r`n$Error[0]" -Log $Log
	exit
} 

if ($Dyn365Connection.IsReady) {
	Write-InformationEventLog -msg "User $($Dyn365Credentials.username) has connected to Dynamics 365 $Dyn365Url successfully." -Log $Log
} else {
	Write-ErrorEventLog -msg "Cannoct connect to Dynamics 365 $Dyn365Url with provided credentials $($Dyn365Credentials.username)." -Log $Log
	exit
}

Invoke-RestMethod   -Headers @{Authorization =("Bearer "+ $Dyn365Connection.OrganizationServiceProxy.SecurityTokenResponse.Token)} `
                        -Uri "$Dyn365Url/$R1000x1000jpg"  `
                        -Method Get
#>

#download data from the internet
function xhrLoad ([string]$url) {
	try {
		$wc = New-Object System.Net.WebClient #define web client
		$start_time = Get-Date                
		$rr = $wc.DownloadData($url)          
	} catch {Write-ErrorEventLog  "$url could not be downloaded"}
	return @{downloadedContentLength = $rr.Length; downloadTime = (Get-Date).Subtract($start_time).TotalMilliSeconds} #return bytes and download time
}

#Run test downloads. $baseurl - the dynamics 365 company url. 
function runDownloadTest ($whatToDownload, $trialsToRun, $baseurl) {
	$isAdaptiveRun = $whatToDownload
	$testResults = @() #save downladed data
    $downloadedContentLength = 0
    $lastRunSpeed = 0
    $prevAdpSpeed = 0

	for ($i = 0; $i -lt $trialsToRun;$i++) { #find the best size for downloading (adaptation)
		$url = ""
		if ($whatToDownload -is [System.Array]) {
            foreach ($adptFile in $whatToDownload) {
				if ($lastRunSpeed -ge $adptFile.speed) {
                    $url = $adptFile.url;
                    if ($prevAdpSpeed -lt $adptFile.speed) {
                        $i = 0;
                        $prevAdpSpeed = $adptFile.speed
                    }
                }
            }
		} else {
			$url = $whatToDownload
		}
		$results = xhrLoad "$($baseurl)$($url)?_rnd=$(Get-Random)"
        $testResults += @{ downloadTime = $results.downloadTime; downloadedContentLength = $results.downloadedContentLength; downloadSpeed = [math]::floor($results.downloadedContentLength * (1e3 / $results.downloadTime) / 1024) }
        $lastRunSpeed = $results.downloadedContentLength * (1e3 / $results.downloadTime) / 1024 / 1024
	}
    [int]$maxDownloadSpeed = $testResults[0].downloadSpeed
	[int]$minDownloadSpeed = $testResults[0].downloadSpeed
    [int]$maxDownloadTime = $testResults[0].downloadTime
	[int]$minDownloadTime = $testResults[0].downloadTime

    foreach ($testResult in $testResults) { #find the max/min download time adn speed
		$maxDownloadSpeed = [math]::Max($maxDownloadSpeed, $testResult.downloadSpeed)
		$minDownloadSpeed = [math]::Min($minDownloadSpeed, $testResult.downloadSpeed)
        $maxDownloadTime = [math]::Max($maxDownloadTime, $testResult.downloadTime)
		$minDownloadTime = [math]::Min($minDownloadTime, $testResult.downloadTime)
	}

    return @{testResults = $testResults;` #return download speed and time
			maxDownloadSpeed = $maxDownloadSpeed;`
			minDownloadSpeed = $minDownloadSpeed;`
			maxDownloadTime = $maxDownloadTime;`
			minDownloadTime = $minDownloadTime}
}

#function to find bandwidth
function runBandwidthTest ($baseurl){
	$adaptionSchedule = @(@{ speed= 0; url= "/_static/Tools/Diagnostics/random100x100.jpg" },` #different size of downloaded data
						@{ speed= .5; url= "/_static/Tools/Diagnostics/random350x350.jpg" },`  #to adapt speed to the current bandwidth
						@{ speed= 1; url= "/_static/Tools/Diagnostics/random750x750.jpg" },`   	
						@{ speed= 2; url= "/_static/Tools/Diagnostics/random1000x1000.jpg" },`
						@{ speed= 4; url= "/_static/Tools/Diagnostics/random1500x1500.jpg" })
	$trialsToRun = 10
	$results = runDownloadTest $adaptionSchedule $trialsToRun $baseurl
	$testResults = $results.testResults
	$i = 0
	$avgDownloadSpeed = 0
    foreach ($testResult in $testResults) {
        $avgDownloadSpeed += $testResult.downloadSpeed
    }
	$avgDownloadSpeed = [math]::floor($avgDownloadSpeed / $testResults.length)
	Write-InformationEventLog -msg "Bandwidth test has been finished. The avarage download speed is $avgDownloadSpeed KB, the max download speed is $maxDownloadSpeed KB/sec and the min download speed is $minDownloadSpeed KB/sec" -Log $Log
    return @{avgDownloadSpeed = $avgDownloadSpeed;maxDownloadSpeed = $results.maxDownloadSpeed;minDownloadSpeed = $results.minDownloadSpeed}
}

#function to find the latency
function runLatencyTest ($baseurl) {
    $trialsToRun = 20
    $results = runDownloadTest "/_static/Tools/Diagnostics/smallfile.txt" $trialsToRun $baseurl
    $testResults = $results.testResults
	$avgDownloadTime = 0
	$i=0
    foreach ($testResult in $testResults) {
        $avgDownloadTime += $testResult.downloadTime
    }
    $avgDownloadTime = [math]::floor($avgDownloadTime / $testResults.length)
	Write-InformationEventLog -msg "Latency test has been finished. The avarage download time is $avgDownloadTime ms." -Log $Log
	return @{avgDownloadTime = $avgDownloadTime;maxDownloadTime = $results.maxDownloadTime;minDownloadTime = $results.minDownloadTime}
}

#function to run sql command
function Invoke-SqlCommand {
	Param (
        [Parameter(Mandatory=$true)][Alias("Serverinstance")][string]$Server, #server name like sqlserver\instancename
        [Parameter(Mandatory=$true)][string]$Database,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Username,
        [Parameter(Mandatory=$true, ParameterSetName="not_integrated")][string]$Password,
        [Parameter(Mandatory=$false, ParameterSetName="integrated")][switch]$UseWindowsAuthentication = $true,
        [Parameter(Mandatory=$true)][string]$Query, #sql command like 'Select * from [tablename]'
        [Parameter(Mandatory=$false)][int]$CommandTimeout=0
    )
    
    #build connection string
    $connstring = "Server=$Server; Database=$Database; "
    If ($PSCmdlet.ParameterSetName -eq "not_integrated") { $connstring += "User ID=$username; Password=$password;" }
    ElseIf ($PSCmdlet.ParameterSetName -eq "integrated") { $connstring += "Trusted_Connection=Yes; Integrated Security=SSPI;" }
    
    #connect to database
    $connection = New-Object System.Data.SqlClient.SqlConnection($connstring)
    $connection.Open()
    
    #build query object
    $command = $connection.CreateCommand()
    $command.CommandText = $Query
    $command.CommandTimeout = $CommandTimeout
    
    #run query
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | out-null
    
    #return the first collection of results or an empty array
    If ($dataset.Tables[0] -ne $null) {$table = $dataset.Tables[0]}
    ElseIf ($table.Rows.Count -eq 0) { $table = New-Object System.Collections.ArrayList }
    
    $connection.Close()
    return $table
}


$BandwidthTest = runBandwidthTest $Dyn365Url
$LatencyTest = runLatencyTest $Dyn365Url

$BadnwidhtLight = switch ($BandwidthTest.avgDownloadSpeed) {
	($_ -le 149){ "good"}
	(($_ -le 249)-and($_ -ge 150)){ "neutral"}
	($_ -ge 250){ "bad"}
}

$LatencyLight = switch ($LatencyTest.avgDownloadTime) {
	($_ -ge 500){ "good"}
	(($_ -le 459)-and($_ -ge 50)){ "neutral"}
	($_ -lt 49){ "bad"}
}

#creation of the insert sql query
$query = "INSERT INTO [dbo].[$TableName] ([DateTime],`
				[AvgBandwidth],`
				[AvgLatency],`
				[UserName],`
				[maxDownloadTime],`
				[minDownloadTime],`
				[maxDownloadSpeed],`
				[minDownloadSpeed]) `
		  VALUES (`'$(get-date -Format "yyyy.MM.dd HH:mm:ss")`',`
				$($BandwidthTest.avgDownloadSpeed),`
				$($LatencyTest.avgDownloadTime),`
				`'$($env:UserName)`',`
				$($LatencyTest.maxDownloadTime),`
				$($LatencyTest.minDownloadTime),`
				$($BandwidthTest.maxDownloadSpeed),`
				$($BandwidthTest.minDownloadSpeed))"
try {
	if ($PSCmdlet.ParameterSetName -eq "sqlauthentication") {
		Invoke-SqlCommand -Server $SQLServerName -Database $DatabaseName -Username $sqlusername -Password $sqluserpassword -Query $query 
		Write-InformationEventLog -msg "Result of latancy and bandwidth tests have been inserted into the database $DatabaseName." -Log $Log
	} else {
		Invoke-SqlCommand -Server $SQLServerName -Database $DatabaseName -UseWindowsAuthentication -Query $query 
		Write-InformationEventLog -msg "Result of latancy and bandwidth tests have been inserted into the database $DatabaseName." -Log $Log
	}
} catch {
	Write-ErrorEventLog -msg "Result of latancy and bandwidth tests could not be inserted into the database $DatabaseName.`
							 `r`n`tPlease check the following error: $($Error[0])" -Log $Log
}