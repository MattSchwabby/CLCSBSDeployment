# CLC-SBS-Deployment

PowerShell script to automate the creation and application of Simple Backup Service policies in a given CenturyLink Cloud account alias.

Author: Matt Schwabenbauer
Date: 4/22/2016
Matt.Schwabenbauer@ctl.io

### Running the script

Before running this script, there are three lines of code that must be manually modified. These are the account alias to execute the script for, the number of days the data will be retained, the backup frequency of the policy, and the storage region where the backups will be stored.

All the modifiable variables begin on line 42.

$retentionDays = 7 # The number of days backup data will be retained
$backupIntervalHours = 12 # The backup frequency of the Policy specified in hours
$storageRegion = "US WEST" # Region where backups are stored, can be "US EAST", "US WEST", "CANADA", "GREAT BRITAIN", "GERMANY", "APAC"
$accountAlias = "XXXX" # The account alias that the Policy and Servers belong to

Once you have set your variables, the script can be executed. An output file with the results of the operation will be created in C:\Users\Public\CLC\SBSDeployment.