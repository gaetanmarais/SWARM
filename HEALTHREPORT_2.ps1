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
####
####
####
####
###################################################################################################################################
###################################################################################################################################




#### Variables

$ADMINURL="https://production.swarm.datacore.paris:91"
$PORTALURL="https://production.swarm.datacore.paris"
$UPLOADURL="https://production.swarm.datacore.paris/public"

$OUTFILE="$env:APPDATA\SwarmHealthReport.html"


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
if (!$cred) {$cred = $host.ui.PromptForCredential("Swarm Domain admin credentials", "Please enter your user name and password.", "", "")}
#if (!$cred) {$cred = Get-Credential}




# Gather SWARM data via REST API commands


# First try is to validate that everything is fine or inform of the error
try {$global:CLUSTER=(Invoke-RestMethod -Uri "$ADMINURL$CLUSTERURL" -Credential $cred)}
catch {
        [System.Windows.MessageBox]::Show("Unable connect $ADMINURL : $Error[0]")
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

write-host "Gather Cluster details"
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

    
    panel {
       $ARRAYCLUSTER|%{
            $VAL=$_
            write "$VAL $($CLUSTERSTATUS.$VAL)<BR>"
            }
    
    $global:LOSSPROTECTION=@()
    (Invoke-RestMethod -TimeoutSec 5 -Uri "$ADMINURL$CLUSTERURL/_self/summary" -Credential $cred).node_loss_protection.node_loss_detail|%{
    $object = New-Object -TypeName PSObject
            $object | Add-Member -Name '# node(s) lost' -MemberType Noteproperty -Value $_.total_nodes_lost
            $object | Add-Member -Name 'Space after node loss' -MemberType Noteproperty -Value $([math]::round(($_.total_space_after_loss/1024),2))
            $object | Add-Member -Name 'Space after recover' -MemberType Noteproperty -Value $([math]::round(($_.available_space_after_recovery/1024),2))
            $object | Add-Member -Name 'Recovery possible?' -MemberType Noteproperty -Value $_.recovery_possible
            $object | Add-Member -Name 'Possible issues' -MemberType Noteproperty -Value $($_.constraints_violated -join "<BR>")
            $global:LOSSPROTECTION+=$object
            }    

    section -name "Nodes loss protection" -CanCollapse {
    panel {
            Table -DataTable ($LOSSPROTECTION)  -DisablePaging -HideFooter -HideButtons -DisableSearch {
                New-TableCondition -Name 'Modified'     -Operator eq -Value "True" -BackgroundColor Green -Color white -ComparisonType string -Inline
                }
        }
    }
    

    section -name "Cluster Variables" -CanCollapse {
    panel {
            Table -DataTable ($CLUSTERSETTINGS)  -DisablePaging -HideFooter -HideButtons {
                New-TableCondition -Name 'Modified'     -Operator eq -Value "True" -BackgroundColor Green -Color white -ComparisonType string -Inline
                }
            }
        }

        }
    New-HTMLSection -HeaderText 'Storage usage' -CanCollapse {
            New-HTMLPanel {
                New-HTMLChart -Gradient {
                    New-ChartPie -Name "Physical Available Space" -Value $global:CLUSTERSTATUS.physicalAvailSpace
                    New-ChartPie -Name 'Physical Used Space' -Value $global:CLUSTERSTATUS.usedSpace
                    New-ChartPie -Name 'Trapped space' -Value $($global:CLUSTERSTATUS.physicalSpace - $global:CLUSTERSTATUS.physicalAvailSpace - $global:CLUSTERSTATUS.usedSpace)
                    }
                }
            }
    New-HTMLSection -HeaderText "License usage : $($global:CLUSTERSTATUS.licensedSpace) " -CanCollapse {
            New-HTMLPanel {
                New-HTMLChart -Gradient {
                    New-ChartPie -Name "License Used Space" -Value $($global:CLUSTERSTATUS.licensedSpace - $global:CLUSTERSTATUS.licensedAvailSpace)
                    New-ChartPie -Name 'License Available Space' -Value $global:CLUSTERSTATUS.licensedAvailSpace
                    
                    }
                }
            }
}

write-host "Gather Nodes details"
Tab -Name 'Storage nodes details' -IconSolid check-circle{
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
            $object | Add-Member -Name 'Used streams' -MemberType Noteproperty -Value $DISKS.'Used streams'[$i]
            $object | Add-Member -Name 'State' -MemberType Noteproperty -Value $DISKS.'State'[$i]
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

    Section -Name "$NAME" -CanCollapse -Collapsed {

        $ARRAY|%{
            $VAL=$_
            write "$VAL $($STATUS.$VAL)<BR>"
            }
            
        panel {
            Table -DataTable ($global:HEALTHDISKS|sort -Property 'name') -Title 'Disks details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'State'        -Operator ne -Value "ok" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                New-TableStyle -TextAlign center 
                }
            Chart -Title 'Disk usage' {
                        ChartBarOptions -Type barStacked100Percent
                        ChartLegend -Names 'Used space', 'Trapped space', 'Journal', 'Free space' -LegendPosition bottom
                        For ($i=0; $i -lt $DISKS.Index.Count; $i++) {
                            ChartBar -Name $DISKS.'Name'[$i] -Value $DISKS.'Used space (MB)'[$i],$DISKS.'Trapped space (MB)'[$i],$DISKS.'write journal capacity (MB)'[$i],$DISKS.'Free space (MB)'[$i]
                            }

                }
            write "<br>"
            Table -DataTable ($global:HEALTHDRIVES|sort -Property 'name') -Title 'Disks details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'Drive state'        -Operator ne -Value "0" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                New-TableStyle -TextAlign center 
                }
            write "<br>"
            Table -DataTable ($global:HEALTHNICS|sort -Property 'Nic Device') -Title 'Network details' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'Nic Up?'        -Operator ne -Value "1" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                New-TableStyle -TextAlign center 
                }
            write "<br>"
            Table -DataTable ($global:HEALTHHPSTATS|select-object "HP *") -Title 'Health Processor' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging {
                New-TableCondition -Name 'Nic Up?'        -Operator ne -Value "1" -BackgroundColor DarkRed -Color white -ComparisonType string -Inline
                New-TableStyle -TextAlign center 
                }
            }
        }
    
    
    }
 }

 write-host "Gather Nodes data protection details"
Tab -Name 'Storage nodes data protection' -IconSolid check-circle{
    $NODES| % {
        $NODE=$_.id
        $NAME=$_.name

        $global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Credential $cred)._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
        $global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Credential $cred)
        $HEALTHREPORTURL=$($STATUS._links."waggle:healthreport".href)
        $global:HEALTHREPORT=(Invoke-RestMethod -Uri "$ADMINURL$HEALTHREPORTURL" -Credential $cred -TimeoutSec 5)
        

    
        Section -Name "$NAME" -CanCollapse -Collapsed {
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
            Table -DataTable $global:HEALTHSTATS -Title 'Protection detail by type and size of objects' -DisableInfo -HideFooter -HideButtons -HideShowButton -DisableSearch -DisableOrdering -DisablePaging  {
                
            }
            }
        }
    
        }
        
}

write-host "Gather Storage usage details"
Tab -Name 'Domains storage usage' -IconSolid check-circle {

    $global:DOMAINUSAGE=@()
    $global:TENANTS=(Invoke-RestMethod -Uri "$PORTALURL$TENANTSURL" -Credential $cred ).name 
    $TENANTS| %{

        $global:TENANT=$_
        Section -Name "$TENANT" -CanCollapse -Collapsed {
        $TENANTBYTEUSER=(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/meter/usage/bytesSize/current?format=json" -Credential $cred )
        $TENANTBYTERAW=(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/meter/usage/bytesStored/current?format=json" -Credential $cred )


        (Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/${TENANT}/domains/?format=json" -Credential $cred)|%{
        $global:DOMAIN=$_.name
        #Write-Host $DOMAIN
        $DOMAINBYTEUSER=try{(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/domains/$DOMAIN/meter/usage/bytesSize/current?format=json" -Credential $cred -ErrorAction Ignore ).bytesSize}
        catch{$DOMAINBYTEUSER=0}
     
        $DOMAINBYTERAW=try{(Invoke-RestMethod -Uri $PORTALURL"/_admin/manage/tenants/$TENANT/domains/$DOMAIN/meter/usage/bytesStored/current?format=json" -Credential $cred -ErrorAction Ignore ).bytesStored}
        catch{$DOMAINBYTERAW=0}

        $DOMAINRAW=$([math]::round($($DOMAINBYTERAW/1GB),2))
        $DOMAINUSER=$([math]::round($($DOMAINBYTEUSER/1GB),2))

        if ( $DOMAINRAW -eq 0 ) {$DOMAINFOOTPRINT=0}
        else { $DOMAINFOOTPRINT = $([math]::round($DOMAINBYTERAW/$DOMAINBYTEUSER,2)) }

         $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value $Domain
            $object | Add-Member -Name 'User Storage usage' -MemberType Noteproperty -Value $DOMAINUSER
            $object | Add-Member -Name 'Raw Storage usage' -MemberType Noteproperty -Value $DOMAINRAW
            $object | Add-Member -Name 'Storage Footprint' -MemberType Noteproperty -Value $DOMAINFOOTPRINT
            $DOMAINUSAGE += $object

        }
        panel {
            Table -DataTable ($DOMAINUSAGE|sort -Descending -Property 'User Storage usage')  -DisablePaging {}
            }

        New-HTMLSection -HeaderText 'User Storage usage' -CanCollapse {
            New-HTMLPanel {
                New-HTMLChart -Gradient {
                    For ($i=0; $i -le $DOMAINUSAGE.Domain.Count; $i++) {
                        New-ChartPie -Name $DOMAINUSAGE.'Domain Name'[$i] -Value $DOMAINUSAGE.'User Storage usage'[$i]
                        }
                    }
                }
            }
        New-HTMLSection -HeaderText "Raw Storage usage" -CanCollapse {
            New-HTMLPanel {
                New-HTMLChart -Gradient {
                    For ($i=0; $i -le $DOMAINUSAGE.Domain.Count; $i++) {
                        New-ChartPie -Name $DOMAINUSAGE.'Domain Name'[$i] -Value $DOMAINUSAGE.'Raw Storage usage'[$i]
                        }
                    
                    }
                }
            }
        }

    }


}

write-host "Gather Protection schema details"
Tab -Name 'Domains protection schema' -IconSolid check-circle {


    section -name "Nodes loss protection" -CanCollapse {
    panel {
            Table -DataTable ($LOSSPROTECTION)  -DisablePaging -HideFooter -HideButtons -DisableSearch {
                New-TableCondition -Name 'Modified'     -Operator eq -Value "True" -BackgroundColor Green -Color white -ComparisonType string -Inline
                }
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
                $object | Add-Member -Name 'Domain name' -MemberType Noteproperty -Value "> $DOMAINNAME"
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
        catch { "Unable to reach $THEDOMAIN" }
    }
        }
        catch { "Unable to reach $PORTALURL" }
    panel {
            Table -DataTable ($PROTECTIONSCHEMA)  -DisablePaging {
                New-TableCondition -Name 'EC policy'             -Operator ne -Value "DEFAULT" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'RF policy'             -Operator ne -Value "DEFAULT" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Versioning policy'     -Operator eq -Value "ENABLED" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking'        -Operator eq -Value "ENABLED" -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Object locking method' -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota bandwidth'       -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline
                New-TableCondition -Name 'Quota storage'         -Operator ne -Value ""        -BackgroundColor Green -Color white -ComparisonType string -Inline
                }
            }
    }

write-host "Gather Health Processor statistics"
Tab -Name 'Health Processor statistics' -IconSolid check-circle {

   
    }

write-host "Gather ElasticSearch statistics"
Tab -Name 'Health ElasticSearch statistics' -IconSolid check-circle {

   
    }
}





