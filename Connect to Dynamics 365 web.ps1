Import-Module Microsoft.Xrm.Data.Powershell
$cred = Get-Credential

#Get connection to the dynamics 365
$dyn365connect = Connect-CrmOnline -Credential $cred -ServerUrl 'https://itvt.crm4.dynamics.com'

Invoke-RestMethod   -Headers @{Authorization =("Bearer "+ $dyn365connect.OrganizationServiceProxy.SecurityTokenResponse.Token)} `
                        -Uri 'https://itvt.crm4.dynamics.com/tools/diagnostics/diag.aspx'  `
                        -Method Get
Invoke-RestMethod   -Headers @{Authorization =("Bearer "+ $dyn365connect.OrganizationServiceProxy.SecurityTokenResponse.Token)} `
                        -Uri 'https://itvt.crm4.dynamics.com/_static/Tools/Diagnostics/random1000x1000.jpg'  `
                        -Method Get
