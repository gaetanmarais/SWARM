###################################################################################################################################
###################################################################################################################################
####
#### SWARM HEALTH REPORT
####
####
#### Author     : Gaetan MARAIS
#### Date       : 22/08/2022
####
####
#### Version    : 1.2  - 29/08/22 - Adding Schema protection tab
####              1.3  - 31/08/22 - Adding Cluster variables to Cluster Tab
####              1.3  - 19-09-22 - Adding Storage details + S3 upload
####              1.4  - 23/09/22 - Adding internode statistics details
####
####
###################################################################################################################################
###################################################################################################################################




#### Variables


$ENABLETAB1=1       #Cluster details
$ENABLETAB2=1       #Nodes details
$ENABLETAB3=1       #Node data protection
$ENABLETAB4=1       #Storage usage
$ENABLETAB5=1       #Protection schema
$ENABLETAB6=1       #Internode statistics
$ENABLETAB7=1
$ENABLETAB8=0
$ENABLEUPLOAD=1


$OUTFILE="$env:APPDATA\index.html"

$NODESURL="/api/storage/nodes"
$CLUSTERURL="/api/storage/clusters"

$TENANTSURL="/_admin/manage/tenants/?format=json"


$ARRAYCLUSTER=@("cluster_name","status","nodeCount","errCount","volErrs","streamCount","usedSpace","physicalSpace","physicalAvailSpace","licensedSpace","maxSpace","availSpace","licensedAvailSpace","physicalAvailPercent","licensedAvailPercent","availPercent","outofsyncCount","offlineCount","logicalObjects","logicalSpace")
$ARRAY=@("clusterName","nodeIPAddress","status","errCount","timestamp","lastHPCycleTm","volErrs","streamCount","maxSpace","usedSpace","availSpace","swVer","upTime","outofsyncCount","availPercent")
$ARRAYPROTECTION=@("policy.eCEncoding","policy.eCMinStreamSize","policy.lifecycle","policy.replicas","policy.versioning","ec.protectionLevel")


#### Script



# install PSWriteHTLM module if not already installed - this module is used to build cool HTML pages :)
if (-not (Get-Module -name PSWriteHTML -ListAvailable)) { Install-Module -name PSWriteHTML -AllowClobber -Force }



# Ask for admin credentials
#if (!$cred) {$cred = $host.ui.PromptForCredential("Swarm Domain admin credentials", "Please enter your user name and password.", "dcsadmin", "")}
#if (!$cred) {$cred = Get-Credential}

$URL=read-host -Prompt "Enter your admin SWARM domain url [https://production.swarm.datacore.paris]"
if ( ! $URL) { $URL="https://production.swarm.datacore.paris"}
if ( $URL -notlike "https://*" -and $URL -notlike "http://*" ) { $URL="https://$URL"}



    $USER=read-host -Prompt "Enter username" 
    

if ( $USER -notlike "*@" ) { $USER="$USER@" }

$PWD=Read-Host -Prompt "Enter $USER password" -AsSecureString 


$global:cred = New-Object System.Management.Automation.PSCredential ($USER, $PWD)



$ADMINURL=$URL+":91"
$PORTALURL="$URL"
$UPLOADURL="$URL/public"




# Gather SWARM data via REST API commands


# First try is to validate that everything is fine or inform of the error
try {$global:CLUSTER=(Invoke-RestMethod -Uri "$ADMINURL$CLUSTERURL" -Credential $cred)}
catch {
        [System.Windows.MessageBox]::Show("Unable connect $ADMINURL : $Error[0]")
        Clear-Variable -Name cred -Scope global
        exit 10
        }


$Global:CLUSTERNAME=$CLUSTER._embedded.clusters.name
$Global:CLUSTERSTATUSURL=$CLUSTER._embedded.clusters._links.self.href
$global:CLUSTERSTATUS=(Invoke-RestMethod -Uri "$ADMINURL$CLUSTERSTATUSURL" -Credential $cred)

$global:SETTINGSURL=$CLUSTERSTATUS._links.'waggle:settings'.href
$global:SETTINGS=(Invoke-RestMethod -Uri "$ADMINURL$SETTINGSURL" -Credential $cred)

$global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Credential $cred)._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
$global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Credential $cred)

$global:NODES=(Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Credential $cred)._embedded.nodes


# This is the cool part with PSWriteHTML module
Dashboard -Name "SWARM Audit - $CLUSTERNAME" -FilePath $OUTFILE -show {

TabOptions -BorderRadius 10px -SlimTabs -Transition   



write-host "1- Gather Cluster details"
if ( $ENABLETAB1 -ne 0 ) {
Tab -Name "$CLUSTERNAME" -IconSolid check-circle{

    $global:CLUSTERSETTINGS=@()
   
    $settings._embedded.settings._links.self.href|%{

    $URL=$_
    $RESULT=(Invoke-RestMethod -Uri "$ADMINURL$URL" -Credential $cred)
    $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $RESULT.name
            $object | Add-Member -Name 'Value' -MemberType Noteproperty -Value $($RESULT.value -join " ")
            $object | Add-Member -Name 'Default' -MemberType Noteproperty -Value $($RESULT.default -join " ")
            $object | Add-Member -Name 'Modified' -MemberType Noteproperty -Value $RESULT.modified
            $object | Add-Member -Name 'Description' -MemberType Noteproperty -Value $RESULT.description

            $global:CLUSTERSETTINGS+=$object
    }

    $global:LOSSPROTECTION=@()
    (Invoke-RestMethod -TimeoutSec 5 -Uri "$ADMINURL$CLUSTERURL/_self/summary" -Credential $cred).node_loss_protection.node_loss_detail|%{
    $object = New-Object -TypeName PSObject
            $object | Add-Member -Name '# node(s) lost' -MemberType Noteproperty -Value $_.total_nodes_lost
            $object | Add-Member -Name 'Space after node loss' -MemberType Noteproperty -Value $([math]::round(($_.total_space_after_loss/1024),2))
            $object | Add-Member -Name 'Space after recover' -MemberType Noteproperty -Value $([math]::round(($_.available_space_after_recovery/1024),2))
            $object | Add-Member -Name 'Recovery possible?' -MemberType Noteproperty -Value $_.recovery_possible
            $object | Add-Member -Name 'Possible issues' -MemberType Noteproperty -Value $($_.constraints_violated -join ",")
            $global:LOSSPROTECTION+=$object
            }    

        New-HTMLTabPanel -Orientation vertical -TransitionAnimation slide-vertical  { 
        New-HTMLTabOptions -BorderRadius 10px -BackgroundColor BlizzardBlue -BorderColor Blue
                New-HTMLTab -Name "Cluster details"  {
                    $ARRAYCLUSTER|%{
                        $VAL=$_
                        New-HTMLText -Text "$VAL $($CLUSTERSTATUS.$VAL)"
                    }
                }
                New-HTMLTab -Name "Nodes loss protection" {
        Table -DataTable ($LOSSPROTECTION)  -DisablePaging -HideFooter -HideButtons -DisableSearch {
                New-TableCondition -Name 'Recovery possible?'     -Operator eq -Value "True" -BackgroundColor DarkGreen -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Recovery possible?'     -Operator eq -Value "False" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                }
        }
                New-HTMLTab -Name 'Lastest Crash'  {
        $HEALTHREPORT.healthreport.'Latest Crash Report'
        }
                New-HTMLTab -Name "Cluster Variables"  {
        Table -DataTable ($CLUSTERSETTINGS)  -DisablePaging -HideFooter -HideButtons {
                New-TableCondition -Name 'Modified'     -Operator eq -Value "True" -BackgroundColor Green -Color white -ComparisonType string -Inline
        }
            
        }
                New-HTMLTab -Name 'Storage usage' {
                    section {
                        New-HTMLSection {
                            New-HTMLChart -Gradient {
                    New-ChartPie -Name "Physical Available Space" -Value $global:CLUSTERSTATUS.physicalAvailSpace
                    New-ChartPie -Name 'Physical Used Space' -Value $global:CLUSTERSTATUS.usedSpace
                    New-ChartPie -Name 'Trapped space' -Value $($global:CLUSTERSTATUS.physicalSpace - $global:CLUSTERSTATUS.physicalAvailSpace - $global:CLUSTERSTATUS.usedSpace)
                    }
                            }
                        New-HTMLSection {
                        New-HTMLChart -Gradient {
                            New-ChartPie -Name "License Used Space" -Value $($global:CLUSTERSTATUS.licensedSpace - $global:CLUSTERSTATUS.licensedAvailSpace)
                            New-ChartPie -Name 'License Available Space' -Value $global:CLUSTERSTATUS.licensedAvailSpace
                            }
                }
                            }
            }
        }
}
}



write-host "2- Gather Nodes details"

if ( $ENABLETAB2 -ne 0 ) {
Tab -Name 'Storage nodes details' -IconSolid check-circle{
    New-HTMLTabPanel -Orientation vertical -TransitionAnimation slide-vertical {
    
    $global:HEALTHINTERNODESTCP=@()
    $global:HEALTHINTERNODESUDP=@()
        $NODES | % {
            $NODE=$_.id
            $NAME=$_.name
    
            $global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Credential $cred)._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
            $global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Credential $cred)
            $HEALTHREPORTURL=$($STATUS._links."waggle:healthreport".href)
            $HEALTHREPORT=(Invoke-RestMethod -Uri "$ADMINURL$HEALTHREPORTURL" -Credential $cred -TimeoutSec 5)

            $STATS=$HEALTHREPORT.healthreport.'SNMP tables'.'HP last cycle: Stream stats'
            $DISKS=$HEALTHREPORT.healthreport.'SNMP tables'.'Volumes Table'
            $DRIVES=$HEALTHREPORT.healthreport.'SNMP tables'.'Drive Table'
            $NICS=$HEALTHREPORT.healthreport.'SNMP tables'.'NIC Table'
            $CONFIG=$HEALTHREPORT.healthreport.'SNMP tables'.'Config Variables Table'
            $ANNOUCEMENT=$HEALTHREPORT.healthreport.'SNMP tables'.'Announcements Table'
            $ERRORTABLE=$HEALTHREPORT.healthreport.'SNMP tables'.'Errors Table'
            $INTERNODESTCP=$HEALTHREPORT.healthreport.'SNMP tables'.'Internode: TCP connection stats'
            $INTERNODESUDP=$HEALTHREPORT.healthreport.'SNMP tables'.'Internode: UDP connection stats'

            $HEALTHHPSTATSURL=$($STATUS._links."waggle:hpstats".href)
            $global:HEALTHHPSTATS=(Invoke-RestMethod -Uri "$ADMINURL$HEALTHHPSTATSURL" -Credential $cred -TimeoutSec 5)

            $global:HEALTHDISKS=@()
            For ($i=0; $i -lt $DISKS.Index.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $DISKS.'Name'[$i]
                $object | Add-Member -Name 'Capacity space (MB)' -MemberType Noteproperty -Value $DISKS.'Capacity space (MB)'[$i]
                $object | Add-Member -Name 'Used space (MB)' -MemberType Noteproperty -Value $DISKS.'Used space (MB)'[$i]
                $object | Add-Member -Name 'Free space (MB)' -MemberType Noteproperty -Value $DISKS.'Free space (MB)'[$i]
                $object | Add-Member -Name 'Trapped space (MB)' -MemberType Noteproperty -Value $DISKS.'Trapped space (MB)'[$i]
                $object | Add-Member -Name 'write journal capacity (MB)' -MemberType Noteproperty -Value $DISKS.'write journal capacity (MB)'[$i]
                $object | Add-Member -Name 'delete journal capacity (MB)' -MemberType Noteproperty -Value $DISKS.'delete journal capacity (MB)'[$i]
                $object | Add-Member -Name 'Used streams' -MemberType Noteproperty -Value $DISKS.'Used streams'[$i]
                $object | Add-Member -Name 'State' -MemberType Noteproperty -Value $DISKS.'State'[$i]
                $object | Add-Member -Name 'Journal Bid' -MemberType Noteproperty -Value $DISKS.'Journal bid'[$i]
                $object | Add-Member -Name 'Error' -MemberType Noteproperty -Value $DISKS.'Error count'[$i]
           
                $global:HEALTHDISKS += $object
                }

            $global:HEALTHDRIVES=@()
            For ($i=0; $i -lt $DRIVES.Index.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $DRIVES.'Drive Name'[$i]
                $object | Add-Member -Name 'drive slot' -MemberType Noteproperty -Value $DRIVES.'drive slot'[$i]
                $object | Add-Member -Name 'drive bus id ' -MemberType Noteproperty -Value $DRIVES.'drive bus id'[$i]
                $object | Add-Member -Name 'drive serial number' -MemberType Noteproperty -Value $DRIVES.'drive serial number'[$i]
                $object | Add-Member -Name 'drive firmware revision level' -MemberType Noteproperty -Value $DRIVES.'drive firmware revision level'[$i]
                $object | Add-Member -Name 'drive state' -MemberType Noteproperty -Value $DRIVES.'drive state'[$i]
                $object | Add-Member -Name 'drive driver' -MemberType Noteproperty -Value $DRIVES.'drive driver'[$i]
                $object | Add-Member -Name 'drive type' -MemberType Noteproperty -Value $DRIVES.'drive type'[$i]
                $global:HEALTHDRIVES += $object
                }

            $global:HEALTHNICS=@()
            For ($i=0; $i -lt $NICS.Index.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'NIC device' -MemberType Noteproperty -Value $NICS.'NIC device'[$i]
                $object | Add-Member -Name 'NIC model' -MemberType Noteproperty -Value $NICS.'NIC model'[$i]
                $object | Add-Member -Name 'NIC speed ' -MemberType Noteproperty -Value $NICS.'NIC speed'[$i]
                $object | Add-Member -Name 'NIC up?' -MemberType Noteproperty -Value $NICS.'NIC up?'[$i]
                $object | Add-Member -Name 'NIC MAC address' -MemberType Noteproperty -Value $NICS.'NIC MAC address'[$i]
                $object | Add-Member -Name 'NIC firmware version' -MemberType Noteproperty -Value $NICS.'NIC firmware version'[$i]
                $object | Add-Member -Name 'NIC driver' -MemberType Noteproperty -Value $NICS.'NIC driver'[$i]
                $object | Add-Member -Name 'NIC driver version' -MemberType Noteproperty -Value $NICS.'NIC driver version'[$i]
                $global:HEALTHNICS += $object
                }

            $global:HEALTHCONFIG=@()
            For ($i=0; $i -lt $CONFIG.'1 - Index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $CONFIG.'2 - Variable name'[$i]
                $object | Add-Member -Name 'Value' -MemberType Noteproperty -Value $CONFIG.'3 - Variable value'[$i]
                $object | Add-Member -Name 'Default' -MemberType Noteproperty -Value $CONFIG.'4 - Default value'[$i]
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $CONFIG.'5 - Value source'[$i]
                if ( $CONFIG.'4 - Default value'[$i] -eq $CONFIG.'3 - Variable value'[$i] ) { $DIFF = "False" } else { $DIFF = "True" }
                $object | Add-Member -Name 'Modified' -MemberType Noteproperty -Value $DIFF
                $global:HEALTHCONFIG += $object
                }

                
            $global:HEALTHANNOUCEMENTS=@()
            For ($i=0; $i -lt $ANNOUCEMENT.'Index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Time Stamp' -MemberType Noteproperty -Value $((Get-Date -Date "01-01-1970") + ([System.TimeSpan]::FromSeconds(($($HEALTHREPORT.healthreport.'SNMP tables'.'Announcements Table'.'Time stamp (secs since epoch)'[$i] -replace (",","."))))))
                $object | Add-Member -Name 'Code' -MemberType Noteproperty -Value $ANNOUCEMENT.'Code'[$i]
                $object | Add-Member -Name 'Text' -MemberType Noteproperty -Value $ANNOUCEMENT.'Text'[$i]
                $global:HEALTHANNOUCEMENTS += $object
                }
            $global:HEALTHERRORS=@()
            For ($i=0; $i -lt $ERRORTABLE.'Index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Time Stamp' -MemberType Noteproperty -Value $((Get-Date -Date "01-01-1970") + ([System.TimeSpan]::FromSeconds(($($HEALTHREPORT.healthreport.'SNMP tables'.'Errors Table'.'Time stamp (secs since epoch)'[$i] -replace (",","."))))))
                $object | Add-Member -Name 'Code' -MemberType Noteproperty -Value $ERRORTABLE.'Code'[$i]
                $object | Add-Member -Name 'Text' -MemberType Noteproperty -Value $ERRORTABLE.'Text'[$i]
                $global:HEALTHERRORS += $object
                }            

                
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Destination' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Attempts' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Successful' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Interrupted' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Not connected' -MemberType Noteproperty -Value "-"
                $global:HEALTHINTERNODESTCP += $object
         
            for ($i=0; $i -lt $INTERNODESTCP.'1 index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Destination' -MemberType Noteproperty -Value $INTERNODESTCP.'2 IP address'[$i]
                $object | Add-Member -Name 'Attempts' -MemberType Noteproperty -Value $INTERNODESTCP.'3 attempts'[$i]
                $object | Add-Member -Name 'Successful' -MemberType Noteproperty -Value $INTERNODESTCP.'4 successful'[$i]
                $object | Add-Member -Name 'Interrupted' -MemberType Noteproperty -Value $INTERNODESTCP.'6 interrupted'[$i]
                $object | Add-Member -Name 'Not connected' -MemberType Noteproperty -Value $INTERNODESTCP.'5 not connected'[$i]
                $global:HEALTHINTERNODESTCP += $object
            }


                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Destination' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Attempts' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Successful' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Stale response' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'No response' -MemberType Noteproperty -Value "-"
                $global:HEALTHINTERNODESUDP += $object            
            for ($i=0; $i -lt $INTERNODESUDP.'1 Index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $NAME
                $object | Add-Member -Name 'Destination' -MemberType Noteproperty -Value $INTERNODESUDP.'2 IP address'[$i]
                $object | Add-Member -Name 'Attempts' -MemberType Noteproperty -Value $INTERNODESUDP.'3 attempts'[$i]
                $object | Add-Member -Name 'Successful' -MemberType Noteproperty -Value $INTERNODESUDP.'4 successful'[$i]
                $object | Add-Member -Name 'Stale response' -MemberType Noteproperty -Value $INTERNODESUDP.'6 stale response'[$i]
                $object | Add-Member -Name 'No response' -MemberType Noteproperty -Value $INTERNODESUDP.'5 no response'[$i]
                $global:HEALTHINTERNODESUDP += $object
            }            
        
            New-HTMLTab -Name "$NAME" {

            New-HTMLTabPanel -Orientation horizontal {
                New-HTMLTab -Name "Node details" {
                    $ARRAY|%{
                    $VAL=$_
                    switch ($VAL)
                    {
                        "lastHPCycleTm" {New-HTMLText -Text "$VAL $([timespan]::fromseconds($($STATUS.$VAL)).tostring("dd\d\ hh\:mm\:ss"))"}
                        "upTime" {New-HTMLText -Text "$VAL $([timespan]::fromseconds($($STATUS.$VAL)).tostring("dd\d\ hh\:mm\:ss"))"}                                               
                        default {New-HTMLText -Text "$VAL $($STATUS.$VAL)"}
                    }
                                        
                    }
                }
                New-HTMLTab -Name "Disk details"  {
                Table -DataTable ($global:HEALTHDISKS|sort -Property 'name') -Title 'Disks details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                    New-TableCondition -Name 'State'        -Operator ne -Value "ok" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                    New-TableCondition -Name 'Error'        -Operator gt -Value 0 -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                    New-TableCondition -Name 'Journal Bid'        -Operator between -Value 10,50 -BackgroundColor Yellow -Color white -ComparisonType string -Inline
                    New-TableCondition -Name 'Journal Bid'        -Operator between -Value 10,80 -BackgroundColor orange -color white -ComparisonType string -Inline
                    New-TableCondition -Name 'Journal Bid'        -Operator between -Value 81,100 -BackgroundColor red -color white -ComparisonType string -Inline
                    New-TableCondition -Name 'Journal Bid'        -Operator gt -Value 100 -BackgroundColor darkred -color white -ComparisonType string -Inline
                    New-TableStyle -TextAlign center 
                }

            Chart {
                        ChartBarOptions -Type barStacked100Percent
                        ChartLegend -Names 'Used space', 'Trapped space', 'Journal write','Journel delete', 'Free space' -LegendPosition bottom
                        For ($i=0; $i -lt $DISKS.Index.Count; $i++) {
                            ChartBar -Name $DISKS.'Name'[$i] -Value $DISKS.'Used space (MB)'[$i],$DISKS.'Trapped space (MB)'[$i],$DISKS.'write journal capacity (MB)'[$i],$DISKS.'delete journal capacity (MB)'[$i],$DISKS.'Free space (MB)'[$i]
                            }

                }
            
            Table -DataTable ($global:HEALTHDRIVES|sort -Property 'name') -Title 'Disks details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'Drive state'        -Operator ne -Value "0" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                New-TableStyle -TextAlign center 
                }
            }
                New-HTMLTab -Name "Network details"  {
                    Table -DataTable ($global:HEALTHNICS|sort -Property 'Nic Device') -Title 'Network details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                        New-TableCondition -Name 'Nic Up?'        -Operator ne -Value "1" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                        New-TableStyle -TextAlign center 
                        }
                
 
                $HEALTHREPORT.healthreport.Device | get-member -MemberType NoteProperty | %  {
                $DEVICE=$_.name



                New-HTMLSection -HeaderText $DEVICE -HeaderTextColor white -HeaderBackGroundColor black {
    

                New-HTMLTable -DataTable ($HEALTHREPORT.healthreport.Device.$DEVICE.receive)  -DisablePaging -DisableOrdering -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch {
                    New-HTMLTableStyle -TextAlign left
                    New-HTMLTableHeader -Title "Receive" -BackGroundColor blue -Color white -Alignment left
                    }
                New-HTMLTable -DataTable ($HEALTHREPORT.healthreport.Device.$DEVICE.transmit)  -DisablePaging -DisableOrdering -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch {
                    New-HTMLTableStyle -TextAlign left
                    New-HTMLTableHeader -Title "Transmit" -BackGroundColor green -Color white -Alignment left
                    }
                }

  }
            }
                New-HTMLTab -Name "Heatlh processor statistics"  {
                    Table -DataTable ($global:HEALTHHPSTATS|select-object "HP *" -ExcludeProperty "HP ongoing*","HP last*" ) -Title 'Health Processor' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {   New-TableStyle -TextAlign center    }
                    Table -DataTable ($global:HEALTHHPSTATS|select-object "HP last*"  ) -Title 'Health Processor'  -Transpose -DisableInfo -HideFooter  -HideButtons -DisableSearch -DisableOrdering -DisablePaging  {   New-TableStyle -TextAlign center    }
                    Table -DataTable ($global:HEALTHHPSTATS|select-object "HP ongoing*"  ) -Title 'Health Processor' -Transpose  -DisableInfo -HideFooter -HideButtons  -DisableSearch -DisableOrdering  -DisablePaging {   New-TableStyle -TextAlign center    }
                    
            }
                New-HTMLTab -Name "Node configuration"  {
                    Table -DataTable ($global:HEALTHCONFIG)  -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                        New-TableCondition -Name 'Modified'        -Operator ne -Value "False"  -BackgroundColor DarkGreen -Color white -ComparisonType string -Inline
                        New-TableStyle -TextAlign center 
                        }
            }            

           
                New-HTMLTab -Name "InterNodes Statistics"  {
                    $TEMP=$global:HEALTHINTERNODESUDP|? {$_.source -eq $name -and $_.source -ne $_.destination} | sort -Property Name
                    New-HTMLText -Text "Internode Statistics : UDP"
                    Table -DataTable ($TEMP)  -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {                        }
            
                Chart {
                        ChartBarOptions -Type bar -Vertical -Gradient 
                        ChartLegend -Names 'Attemps','Successfull','Stale response','No response' -LegendPosition bottom
                        For ($i=0; $i -lt $TEMP.destination.Count; $i++) {
                            ChartBar -Name $TEMP.destination[$i] -Value $TEMP.'Attempts'[$i],$TEMP.'Successful'[$i],$TEMP.'Stale response'[$i],$TEMP.'No response'[$i]
                            }
                        }


                    New-HTMLText -Text "Internode Statistics : TCP"
                    $TEMP=$global:HEALTHINTERNODESTCP|? {$_.source -eq $name -and $_.source -ne $_.destination} | sort -Property Name
                    Table -DataTable ($global:TEMP|? {$_.source -eq $name} | sort -Property Name)  -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {                        }
                    Chart {
                        ChartBarOptions -Type bar -Vertical -Gradient
                        ChartLegend -Names 'Attemps','Successfull','Interrupted','Not connected' -LegendPosition bottom
                        For ($i=0; $i -lt $TEMP.destination.Count; $i++) {
                            ChartBar -Name $TEMP.destination[$i] -Value $TEMP.'Attempts'[$i],$TEMP.'Successful'[$i],$HEALTHINTERNODESTCP.'Interrupted'[$i],$HEALTHINTERNODESTCP.'Not connected'[$i]
                            }
                        }

            }

            New-HTMLTab -Name "Node events"  {
                    Table -DataTable ($global:HEALTHANNOUCEMENTS)  -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {    
                     }
            }            
            New-HTMLTab -Name "Node errors"  {
                    Table -DataTable ($global:HEALTHERRORS)  -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {    
                     }
            }            

            }
        }
    }
 }
}
}



write-host "3- Gather Nodes data protection details"
if ( $ENABLETAB3 -ne 0 ) {
Tab -Name 'Storage nodes data protection' -IconSolid check-circle{
    New-HTMLTabPanel -Orientation vertical -TransitionAnimation slide-vertical  {
        $NODES| % {
            $NODE=$_.id
            $NAME=$_.name

            $global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Credential $cred)._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
            $global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Credential $cred)
            $HEALTHREPORTURL=$($STATUS._links."waggle:healthreport".href)
            $global:HEALTHREPORT=(Invoke-RestMethod -Uri "$ADMINURL$HEALTHREPORTURL" -Credential $cred -TimeoutSec 5)
        
        
            New-HTMLTab -Name "$NAME"  {
        $STATS=$HEALTHREPORT.healthreport.'SNMP tables'.'HP last cycle: Stream stats'

        $global:HEALTHSTATS=@()
        For ($i=0; $i -lt $STATS.Index.Count; $i++) {
            $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Stream Type' -MemberType Noteproperty -Value $STATS.'Stream Type'[$i]
            $object | Add-Member -Name 'Size Bound' -MemberType Noteproperty -Value $("{0:n0}" -f $STATS.'Size Bound'[$i])
            $object | Add-Member -Name 'Count' -MemberType Noteproperty -Value $("{0:n0}" -f $STATS.'Count'[$i])
            $object | Add-Member -Name 'Encoding' -MemberType Noteproperty -Value $STATS.'Encoding'[$i]
            $object | Add-Member -Name 'Need consolidation' -MemberType Noteproperty -Value $STATS.'Need consolidation'[$i]
            $object | Add-Member -Name 'Need implicit conversion' -MemberType Noteproperty -Value $STATS.'Need implicit conversion'[$i]
            $object | Add-Member -Name 'Need policy conversion' -MemberType Noteproperty -Value $STATS.'Need policy conversion'[$i]

            $global:HEALTHSTATS += $object
            }

        panel {
            Table -DataTable ($global:HEALTHSTATS) -Title 'Protection detail by type and size of objects' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'Need consolidation' -Operator ne -Value 0 -BackgroundColor DarkGreen -Color White
                New-TableCondition -Name 'Need implicit conversion' -Operator ne -Value 0 -BackgroundColor DarkGreen -Color White
                New-TableCondition -Name 'Need policy conversion' -Operator ne -Value 0 -BackgroundColor DarkGreen -Color White                
            }
            }
        }
            }
        }
        
}
}



write-host "4- Gather Storage usage details"
if ( $ENABLETAB4 -ne 0 ) {
Tab -Name 'Domains storage usage' -IconSolid check-circle {

    $global:DOMAINUSAGE=@()
    $global:TENANTS=(Invoke-RestMethod -Uri "$PORTALURL$TENANTSURL" -Credential $cred ).name 
    New-HTMLTabPanel -Orientation vertical -TransitionAnimation slide-vertical    {

    $TENANTS| %{

        $global:TENANT=$_
        New-HTMLTab -Name "$TENANT"  {
        section {
        $TENANTBYTEUSER=(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/meter/usage/bytesSize/current?format=json" -Credential $cred )
        $TENANTBYTERAW=(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/meter/usage/bytesStored/current?format=json" -Credential $cred )
        $TENANTOBJECTS=(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/meter/usage/objectsStored/current?format=json" -Credential $cred )


        (Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/${TENANT}/domains/?format=json" -Credential $cred)|%{
        $global:DOMAIN=$_.name
        $DOMAINBYTEUSER=try{(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/domains/$DOMAIN/meter/usage/bytesSize/current?format=json" -Credential $cred -ErrorAction Ignore ).bytesSize}
           catch{$DOMAINBYTEUSER=[int][math]::0}
        $DOMAINBYTERAW=try{(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/domains/$DOMAIN/meter/usage/bytesStored/current?format=json" -Credential $cred -ErrorAction Ignore ).bytesStored}
           catch{$DOMAINBYTERAW=[int][math]::0}
        $DOMAINOBJECTS=try{(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/domains/$DOMAIN/meter/usage/objectsStored/current?format=json" -Credential $cred -ErrorAction Ignore ).objectsStored}
           catch{$DOMAINOBJECTS=[int][math]::0}



        $DOMAINRAW=$([math]::round($($DOMAINBYTERAW/1GB),2))
        $DOMAINUSER=$([math]::round($($DOMAINBYTEUSER/1GB),2))
        $DOMAINOBJECTS=$([math]::Floor($DOMAINOBJECTS/1))

        if ( $DOMAINRAW -eq 0 ) {$DOMAINFOOTPRINT=0}
        else { $DOMAINFOOTPRINT = $([math]::round($DOMAINBYTERAW/$DOMAINBYTEUSER,2)) }


         $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value $Domain
            $object | Add-Member -Name 'User Storage usage (GB)' -MemberType Noteproperty -Value $DOMAINUSER
            $object | Add-Member -Name 'Raw Storage usage (GB)' -MemberType Noteproperty -Value $DOMAINRAW
            $object | Add-Member -Name 'Storage Footprint' -MemberType Noteproperty -Value $DOMAINFOOTPRINT
            $object | Add-Member -Name 'Objects Stored' -MemberType Noteproperty -Value $DOMAINOBJECTS.Tostring('### ### ##0')
            $DOMAINUSAGE += $object

        }
        New-HTMLSection -HeaderText "Storage usage table" {
                Table -DataTable ($DOMAINUSAGE|sort -Descending -Property 'User Storage usage (GB)')  -DisablePaging -DataTableID 'StoUsage' {
                }
            }

        New-HTMLSection -HeaderText 'User Storage usage' {
                New-HTMLChart -Gradient {
                    For ($i=0; $i -le $DOMAINUSAGE.Domain.Count; $i++) {
                        New-ChartPie -Name $DOMAINUSAGE.'Domain Name'[$i] -Value $DOMAINUSAGE.'User Storage usage (GB)'[$i]
                        }
                    New-ChartEvent -DataTableID 'StoUsage' -ColumnID 0
                }
            }
        New-HTMLSection -HeaderText "Raw Storage usage"  {
                New-HTMLChart -Gradient {
                    For ($i=0; $i -le $DOMAINUSAGE.Domain.Count; $i++) {
                        New-ChartPie -Name $DOMAINUSAGE.'Domain Name'[$i] -Value $DOMAINUSAGE.'Raw Storage usage (GB)'[$i]
                        }
                    New-ChartEvent -DataTableID 'StoUsage' -ColumnID 0
                }
            }
        }
        }

    }
    }


}
}



write-host "5- Gather Protection schema details"
if ( $ENABLETAB5 -ne 0 ) {
Tab -Name 'Domains protection schema' -IconSolid check-circle {


    section -name "Nodes loss protection" {
            Table -DataTable ($LOSSPROTECTION)  -DisablePaging -HideFooter -HideButtons -DisableSearch {
                New-TableCondition -Name 'Recovery possible?'     -Operator eq -Value "True" -BackgroundColor DarkGreen -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Recovery possible?'     -Operator eq -Value "False" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                }
    }

    section -name 'Cluster default settings' {

        Table -DataTable ($CLUSTERSETTINGS | ?{$_.name -in $ARRAYPROTECTION}|Select-Object -Property 'Name','Value')  -DisablePaging -HideFooter -HideButtons -DisableSearch {}


    }

        $global:PROTECTIONSCHEMA=@()
               
        try{$DOMAINSDETAILS=(Invoke-RestMethod -Uri $PORTALURL"?domains&format=json&fields=*" -Credential $cred)

        $DOMAINSDETAILS|sort -Property 'x_tenant_meta_name','name' |%{

        $global:DOMAINTENANT=$_.x_tenant_meta_name
        $global:DOMAINNAME=$_.name
        $DOMAINBUCKET=""
        

        if ( ! $_.policy_ecencoding )           { $ECPOLICY = "DEFAULT" }      else { $ECPOLICY = ($_.policy_ecencoding).toupper()}
        if ( ! $_.policy_replicas )             { $RFPOLICY = "DEFAULT" }      else { $RFPOLICY = ($_.policy_replicas).toupper()}
        if ( ! $_.policy_versioning )           { $VERSPOLICY = "DEFAULT" }    else { $VERSPOLICY = ($_.policy_versioning).toupper()}
        if ( ! $_.x_object_lock_meta_status )   { $LOCKPOLICY = "DISABLED" }   else { $LOCKPOLICY = ($_.x_object_lock_meta_status).toupper()}

        
        $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Tenant name' -MemberType Noteproperty -Value $DOMAINTENANT
            $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value $DOMAINNAME
            $object | Add-Member -Name 'Bucket' -MemberType Noteproperty -Value $DOMAINBUCKET
            $object | Add-Member -Name 'EC policy' -MemberType Noteproperty -Value $ECPOLICY
            $object | Add-Member -Name 'RF policy' -MemberType Noteproperty -Value $RFPOLICY
            $object | Add-Member -Name 'Versioning policy' -MemberType Noteproperty -Value $VERSPOLICY
            $object | Add-Member -Name 'Object locking' -MemberType Noteproperty -Value $LOCKPOLICY
            $object | Add-Member -Name 'Object locking method' -MemberType Noteproperty -Value $_.x_object_lock_meta_default
            $object | Add-Member -Name 'Quota bandwidth' -MemberType Noteproperty -Value $_.x_caringo_meta_quota_bandwidth_limit
            $object | Add-Member -Name 'Quota storage' -MemberType Noteproperty -Value $_.x_caringo_meta_quota_storage_limit
            $PROTECTIONSCHEMA += $object

        $THEDOMAINNAME="https://$($_.name)"
        try{
            $BUCKETSDETAILS=(Invoke-RestMethod -Uri $THEDOMAINNAME"?format=json&fields=*" -Credential $cred)
            $BUCKETSDETAILS|sort -Property 'name'|%{

            if ( ! $_.policy_ecencoding )           { $ECPOLICY = "DEFAULT" }      else { $ECPOLICY = ($_.policy_ecencoding).toupper()}
            if ( ! $_.policy_replicas )             { $RFPOLICY = "DEFAULT" }      else { $RFPOLICY = ($_.policy_replicas).toupper()}
            if ( ! $_.policy_versioning )           { $VERSPOLICY = "DEFAULT" }    else { $VERSPOLICY = ($_.policy_versioning).toupper()}
            if ( ! $_.x_object_lock_meta_status )   { $LOCKPOLICY = "DISABLED" }   else { $LOCKPOLICY = ($_.x_object_lock_meta_status).toupper()}
            $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Tenant name' -MemberType Noteproperty -Value $DOMAINTENANT
                $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value $DOMAINNAME
                $object | Add-Member -Name 'Bucket' -MemberType Noteproperty -Value $_.name
                $object | Add-Member -Name 'EC policy' -MemberType Noteproperty -Value $ECPOLICY
                $object | Add-Member -Name 'RF policy' -MemberType Noteproperty -Value $RFPOLICY
                $object | Add-Member -Name 'Versioning policy' -MemberType Noteproperty -Value $VERSPOLICY
                $object | Add-Member -Name 'Object locking' -MemberType Noteproperty -Value $LOCKPOLICY
                $object | Add-Member -Name 'Object locking method' -MemberType Noteproperty -Value $_.x_object_lock_meta_default
                $object | Add-Member -Name 'Quota bandwidth' -MemberType Noteproperty -Value $_.x_caringo_meta_quota_bandwidth_limit
                $object | Add-Member -Name 'Quota storage' -MemberType Noteproperty -Value $_.x_caringo_meta_quota_storage_limit
                $PROTECTIONSCHEMA += $object

            }
            }
        catch { 
            $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Tenant name' -MemberType Noteproperty -Value $DOMAINTENANT
                $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value $DOMAINNAME
                $object | Add-Member -Name 'Bucket' -MemberType Noteproperty -Value "Unable to browse buckets"
                $object | Add-Member -Name 'EC policy' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'RF policy' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Versioning policy' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Object locking' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Object locking method' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Quota bandwidth' -MemberType Noteproperty -Value "-"
                $object | Add-Member -Name 'Quota storage' -MemberType Noteproperty -Value "-"
                $PROTECTIONSCHEMA += $object                
                
                }
    }
        }
        catch { "** Unable to reach $PORTALURL" }
    Section -Name "Protection schema"   {
            Table -DataTable ($PROTECTIONSCHEMA)  -DisablePaging {
                New-TableCondition -Name 'EC policy'             -Operator ne -Value "DEFAULT" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'RF policy'             -Operator ne -Value "DEFAULT" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Versioning policy'     -Operator eq -Value "ENABLED" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking'        -Operator eq -Value "ENABLED" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking method' -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota bandwidth'       -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota storage'         -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline

                New-TableCondition -Name 'Bucket'             -Operator eq -Value "Unable to browse buckets"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'EC policy'             -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'RF policy'             -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Versioning policy'     -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking'        -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking method' -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota bandwidth'       -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota storage'         -Operator eq -Value "-"        -BackgroundColor Orange -Color white -ComparisonType string -Inline


                New-TableRowGrouping -Name 'Domain name' -SortOrder Ascending

                }
            }
    }
}



write-host "6- Gather Internodes statistics"
if ( $ENABLETAB6 -ne 0 ) {
Tab -Name 'Internodes statistics' -IconSolid check-circle {


#TCP
$GROUPTCP = ($HEALTHINTERNODESTCP |  sort -Property source | Group-Object -Property source)

$PIVOTTCP = foreach ($dg in $GROUPTCP) {

   $props = @(
        @{ Name = "-" ; Expression = { ($dg.Group | Select-Object -ExpandProperty source -Unique) }}
        foreach ($dest in  ($dg.Group | Select-Object -ExpandProperty destination | sort -Unique)  ) {
            @{ 
                Name = "$dest"
                Expression = { " $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Successful"") ($([math]::round($(100*$($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Successful"")/$($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Attempts"")),2))%)" }.GetNewClosure()
            }
        }

    )
 
    $dg | Select-Object $props 

 }

$ERRORSTCP = foreach ($dg in $GROUPTCP) {

   $props = @(
        @{ Name = "TCP: Interrupted + Not connected" ; Expression = { ($dg.Group | Select-Object -ExpandProperty source -Unique) }}
        foreach ($dest in  ($dg.Group | Select-Object -ExpandProperty destination | sort -Unique)  ) {
            @{ 
                Name = "$dest"
                Expression = { " $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""interrupted"") + $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""not connected"") " }.GetNewClosure()
            }
        }

    )
 
    $dg | Select-Object $props 

 }


#UDP
$GROUPUDP = ($HEALTHINTERNODESUDP |  sort -Property source | Group-Object -Property source)


$PIVOTUDP = foreach ($dg in $GROUPTCP) {

   $props = @(
        @{ Name = "-" ; Expression = { ($dg.Group | Select-Object -ExpandProperty source -Unique) }}
        foreach ($dest in  ($dg.Group | Select-Object -ExpandProperty destination | sort -Unique)  ) {
            @{ 
                Name = "$dest"
                Expression = { " $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Successful"") ($([math]::round($(100*$($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Successful"")/$($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Attempts"")),2))%)" }.GetNewClosure()
            }
        }

    )
 
    $dg | Select-Object $props 

 }

$ERRORSUDP = foreach ($dg in $GROUPUDP) {

   $props = @(
        @{ Name = "-" ; Expression = { ($dg.Group | Select-Object -ExpandProperty source -Unique) }}
        foreach ($dest in  ($dg.Group | Select-Object -ExpandProperty destination | sort -Unique)  ) {
            @{ 
                Name = "$dest"
                Expression = { " $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""Stale response"") + $($dg.Group | Where-Object destination -eq $dest | Select-Object -ExpandProperty ""no response"") " }.GetNewClosure()
            }
        }

    )
 
    $dg | Select-Object $props 

 }





Section -Name "TCP network traffic"   {
            
                Table -DataTable ($PIVOTTCP) -HideButtons -DisableSearch -HideFooter -DisablePaging -DisableOrdering -DisableInfo {            }
            }

Section -Name "TCP errors : Intterupted + Not connected"   {
            
                Table -DataTable ($ERRORSTCP) -HideButtons -DisableSearch -HideFooter -DisablePaging -DisableOrdering -DisableInfo {            }
            }

Section -Name "UDP network traffic"   {

                Table -DataTable ($PIVOTUDP) -HideButtons -DisableSearch -HideFooter  -DisablePaging -DisableOrdering -DisableInfo {           }
            }
Section -Name "UDP errors : Stale response + No response"   {

                Table -DataTable ($ERRORSUDP) -HideButtons -DisableSearch -HideFooter  -DisablePaging -DisableOrdering -DisableInfo {           }
            }
   
    }
}



write-host "7- Gather ElasticSearch statistics"
if ( $ENABLETAB7 -ne 0 ) {
Tab -Name 'Health ElasticSearch statistics' -IconSolid check-circle {


$global:SEARCHFEEDS=(Invoke-RestMethod -Uri "$ADMINURL/api/storage/searchfeeds" -Credential $cred)
$global:REPLICAFEEDS=(Invoke-RestMethod -Uri "$ADMINURL/api/storage/replicationfeeds" -Credential $cred)

$SEARCHFEEDS|% {
    $SEARCHFEEDID=$_._embedded.searchfeeds.id
    $SEARCHFEEDNAME=$_._embedded.searchfeeds.name
    $global:SEARCHFEEDHEALTH=(Invoke-RestMethod -Uri "$ADMINURL/api/storage/searchfeeds/$SEARCHFEEDID/health" -Credential $cred)


    switch -Wildcard ($SEARCHFEEDHEALTH.overallFeedState)
    {
    OK { $FEEDCOLOR="green" }
    Paused* {$FEEDCOLOR="orange"}
    default {$FEEDCOLOR="red"}
    }    

    $global:SEARCHFEEDSTATE=@()
    $SEARCHFEEDHEALTH.nodeStates | %{
        $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Plugin State' -MemberType Noteproperty -Value $_.pluginState
            $object | Add-Member -Name 'Feed Status' -MemberType Noteproperty -Value $_.feedState
            $object | Add-Member -Name 'Node Reporting' -MemberType Noteproperty -Value ($_.nodesReporting -join ",")
            
            $global:SEARCHFEEDSTATE+=$object

            }
    New-HTMLSection -HeaderText "Search feed : $SEARCHFEEDID - $SEARCHFEEDNAME ($($SEARCHFEEDHEALTH.overallFeedState))" -HeaderBackGroundColor $FEEDCOLOR -HeaderTextColor white {
       New-HTMLtable -DataTable ($SEARCHFEEDSTATE) -DisablePaging -DisableOrdering -DisableInfo -HideFooter -HideShowButton -HideButtons -DisableSearch { }
    }
    Section -Invisible {
       table -DataTable ($SEARCHFEEDHEALTH|Select-Object -Property * -ExcludeProperty nodestates,_links) -DisablePaging -DisableOrdering -DisableInfo -HideFooter -HideButtons -Transpose  -DisableSearch { }
    }

}

$REPLICAFEEDS|% {
    $REPLICAFEEDID=$_._embedded.replicationfeeds.Id
    $REPLICAFEEDNAME=$_._embedded.replicationfeeds.Name
    if ( $REPLICAFEEDID ) {
    $global:REPLICAFEEDHEALTH=(Invoke-RestMethod -Uri "$ADMINURL/api/storage/replicationfeeds/$REPLICAFEEDID/health" -Credential $cred)


    switch -Wildcard ($REPLICAFEEDHEALTH.overallFeedState)
    {
    OK { $FEEDCOLOR="green" }
    Paused* {$FEEDCOLOR="orange"}
    default {$FEEDCOLOR="red"}
    }    

    $global:REPLICAFEEDSTATE=@()
    $REPLICAFEEDHEALTH.nodeStates | %{
        $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Plugin State' -MemberType Noteproperty -Value $_.pluginState
            $object | Add-Member -Name 'Feed Status' -MemberType Noteproperty -Value $_.feedState
            $object | Add-Member -Name 'Node Reporting' -MemberType Noteproperty -Value ($_.nodesReporting -join ",")
            
            $global:REPLICAFEEDSTATE+=$object

            }
    New-HTMLSection -HeaderText "Replica feed : $REPLICAFEEDID - $REPLICAFEEDNAME ($($REPLICAFEEDHEALTH.overallFeedState))" -HeaderBackGroundColor $FEEDCOLOR -HeaderTextColor white {
       New-HTMLtable -DataTable ($REPLICAFEEDSTATE) -DisablePaging -DisableOrdering -DisableInfo -HideFooter -HideShowButton -HideButtons -DisableSearch { }
    }
    Section -Invisible {
      Table -DataTable ($REPLICAFEEDHEALTH|Select-Object -Property * -ExcludeProperty nodestates,_links) -DisablePaging -DisableOrdering -DisableInfo -HideFooter -Transpose -HideButtons -DisableSearch { }
    }
    }
}
}
}
}

write-host "Upload file to $URL"
if ( $ENABLEUPLOAD -ne 0 ) {
Write-S3Object -EndpointUrl "https://production.swarm.datacore.paris" -BucketName public -File $OUTFILE -AccessKey 'fe21d670639ab94e017a0fd091283881' -SecretKey 'P@ssw0rd'
}