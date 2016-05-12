<#
Script to create and apply a Simple Backup Service retention policy to all CenturyLink Cloud servers in a given account
Author: Matt Schwabenbauer
Created: April 20, 2016
Matt.Schwabenbauer@ctl.io

This script will iterate through every server in a given account alias, detect which storage paths are being used, and create SBS policies for the associated OS for those paths.
Separate policies will be created for Windows and Linux, and the storage paths will be appropriately assigned to each.

There are a number of variables you may want to change before running this script. These variables begin on line 43.
If you do not modify the account alias before running the script, you will be prompted for an alias before execution.

Before any changes are made, you will be notified of the backup policy settings and the account they will be applied to. You will be prompted to continue execution.

An output file with results of the operation will be stored in C:\users\public\CLC\SBSDeployment.

#>

# Instruct PowerShell to use TLS version 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Tell the user about this script
Write-Verbose -message "This script will iterate through Virtual Machines in a given CenturyLink Cloud account alias and apply a Simple Backup Service policy to them." -verbose

# Create directory to store .txt file with results of the operation
New-Item -ItemType Directory -Force -Path C:\Users\Public\CLC\SBSDeployment

# API V2 Login: Creates $HeaderValue for Passing Auth. Displays $error variable if the login fails, and exits the script.
Write-Verbose "Logging in to CenturyLink Cloud v2 API." -Verbose
try
{
$global:CLCV2cred = Get-Credential -message "Please enter your CenturyLink Cloud Control Portal credentials." -ErrorAction Stop 
$body = @{username = $CLCV2cred.UserName; password = $CLCV2cred.GetNetworkCredential().password} | ConvertTo-Json 
$global:resttoken = Invoke-RestMethod -uri "https://api.ctl.io/v2/authentication/login" -ContentType "Application/JSON" -Body $body -Method Post 
$HeaderValue = @{Authorization = "Bearer " + $resttoken.bearerToken}
}
catch
{
Write-Verbose "Login information is incorrect. Terminating operation."
$error[0]
exit
}

# Variables to be modified
$retentionDays = 7 # The number of days backup data will be retained
$backupIntervalHours = 12 # The backup frequency of the Policy specified in hours
$storageRegion = "US WEST" # Region where backups are stored, can be "US EAST", "US WEST", "CANADA", "GREAT BRITAIN", "GERMANY", "APAC"
$accountAlias = "MSCH" # The account alias that the Policy and Servers belong to

if ($accountAlias -eq "XXXX")
{
    $accountAlias = Read-Host "Please enter the account alias you would like to apply a Simple Backup Service policy to"
}
else
{
    # Do nothing
}

$continue = Read-Host "Applying a $retentionDays day backup retention policy with $backupIntervalHours hour intervals storing data in $storageRegion to account alias $accountAlias. Confirm? (Y/N)"

if ($continue -eq "Y")
{
    # Do nothing
}
else
{
    Write-Verbose "Operation terminated."
    exit
}

# Session scope variables that should not be modified
$body = $null
$myServers = @()
$paths = @()
$server = $null
$myServer = $null
$dataCenter = $null
$dataCenters = $null
$serverDetails = @()
$winPaths = @()
$linPaths = @()
$thispath = $null
$OSes = @("Windows";"Linux") # The script will automatically assign the appropriate OS based policy for the system
$month = get-date -Uformat %b
$day = get-date -Uformat %d
$year = get-date -Uformat %Y
$timestamp = Get-Date
$todaysDate = "$month $day $year"
$SBSName = "SBS Policy Created for $OS from the API on $todaysDate"
$winPolicy = @()
$linPolicy = @()
$filename = "C:\Users\Public\CLC\SBSDeployment\$accountAlias-$month-$day-$year-SBSDeploymentResults.txt" # Variable to store the filename of the output file for the results of this operation

Write-Verbose -message "Beginning main operation. The results will be stored in an output file located at $filename." -verbose

# Function to get details about a given server in a given account alias
function getServer
{
    $server = $args[0]
    $url = "https://api.ctl.io/v2/servers/$accountAlias/$server"
    $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
    return $result
} # end getServer

# Function to get the available CLC data centers
function getDataCenters
{
    $url = "https://api.backup.ctl.io/clc-backup-api/api/datacenters"
    $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
    return $result
} # end getDataCenters

# Function to get the available servers in a given data center
function getMyServers
{
    $dataCenter = $args[0]
    $url = "https://api.backup.ctl.io/clc-backup-api/api/datacenters/$dataCenter/servers"
    $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -Method Get
    return $result
} # end getMyServers

# Function to create Simple Backup policies
function createPolicy
{
    if ($OS -eq "Windows")
    {
        $paths = [array]$winPaths
        $SBSName = "SBS Policy Created for Windows from the API on $todaysDate"
    } # end if
    else
    {
        $paths = [array]"/" # Since Linux file paths roll up to /, backing up / will backup the entire file system of any Linux machine
        $SBSName = "SBS Policy Created for Linux from the API on $todaysDate"
    } # end else
    $url = "https://api.backup.ctl.io/clc-backup-api/api/accountPolicies"
    $body = @{backupIntervalHours = $backupIntervalHours; clcAccountAlias = $accountAlias; name = $SBSName; osType = $OS; paths = $paths; retentionDays =  $retentionDays } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -body $body -Method Post
    $result
    Add-Content $filename "$timestamp $OS SBS Policy created for Account Alias: $accountAlias."
    Add-Content $filename "Policy Details: $result"
    if ($OS -eq "Windows")
    {
        Set-Variable -Name winPolicy -Value ($result.policyId) -scope Global
        "$OS policy id is"
        $winPolicy
    } # end if
    else
    {
        Set-Variable -Name linPolicy -Value ($result.policyId) -scope Global
        "$OS policy id is"
        $linPolicy
    } # end else
} # end createPolicy

# Function to apply a given SBS policy to a given Server ID
function applyPolicy
{
    $policy = $args[0]
    "Applying SBS policy $policy to $thisid"
    $url = "https://api.backup.ctl.io/clc-backup-api/api/accountPolicies/$policy/serverPolicies"
    $body = @{clcAccountAlias = $accountAlias; serverId = $thisid; storageRegion = $storageRegion} | ConvertTo-Json
    $result = Invoke-RestMethod -Uri $url -ContentType "Application/JSON" -Headers $HeaderValue -body $body -Method Post
    $result
    Add-Content $filename "$timestamp SBS Policy $policy applied to server $thisid."
    Add-Content $filename "Policy Details: $result"
} # end applyPolicy


<# Begin Main Script #>

# Create a variable to hold the list of available data centers by calling getDataCenters
$dataCenters = getDataCenters

# Create a variable containing all of our existing servers
forEach ($dataCenter in $dataCenters)
{
    $myServers += getMyServers($dataCenter)
} # end forEach

# Display the getServer details for each server
forEach ($myServer in $myServers)
{
    $serverDetails += getserver($myServer)
} # end forEach

#store the details of the available storage paths
forEach ($serverDetail in $serverDetails)
{

    $thesePaths = $serverDetail.details.partitions.path
    forEach ($thisPath in $thesePaths)
    {
        if ($thispath.startsWith("/"))
        {
            # Do nothing for Linux paths
        } # end if
        elseif ($thispath.startsWith("(swap)")) # Remove Linux swap paths as SBS will not back these up
        {
            # Do nothing for swap paths
        } # end elseif
        else
        {
            $winPaths += $thisPath
        } # end else
    } # end forEach
} # end forEach

# Remove duplicate paths in the $winPaths array
$winPaths = $winPaths | select-object -unique

"Linux path that will be backed up is /"
"Windows paths that will be backed up are $winpaths"

# Create Simple Backup Policies
forEach ($OS in $OSes)
{
    "Creating policy for $OS."
    createPolicy
} # end forEach

# Apply policies to servers
forEach ($Server in $serverDetails)
{
    $thisOS = $Server.ostype
    $thisid = $Server.id
    if ($thisOS.startsWith("Windows"))
    {
        "$thisid is a $thisOS server"
        applyPolicy($winPolicy)
    } # end if
    else
    {
        "$thisid is a $thisOS server"
        applyPolicy($linPolicy)
    } # end else
} # end forEach

 Write-Verbose -message "Operation complete. An output file with results will be stored at $filename." -verbose