

$NODESURL="/api/storage/nodes"
$CLUSTERURL="/api/storage/clusters"


#### Script


# TLS12 security protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


$URL=read-host -Prompt "Enter your STRORAGE SWARM url [https://production.swarm.datacore.paris:91]"
if ( ! $URL) { $URL="https://production.swarm.datacore.paris:91"}
if ( $URL -notlike "https://*" -and $URL -notlike "http://*" ) { $URL="https://$URL"}


$USER=read-host -Prompt "Enter username" 
    
if ( $USER -notlike "*@" ) { $USER="!$USER@" }

$PWD=Read-Host -Prompt "Enter $USER password" -AsSecureString 


$global:cred = New-Object System.Management.Automation.PSCredential ($USER, $PWD)


$pair = "$($USER):$([System.Runtime.InteropServices.Marshal]::PtrToStringUni([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($PWD)))"
$global:encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))


$ADMINURL=$URL
$PORTALURL="$URL"



# Gather SWARM data via REST API commands


# First try is to validate that everything is fine or inform of the error
try {$global:CLUSTER=(Invoke-RestMethod -Uri "$ADMINURL$CLUSTERURL" -Headers @{Authorization = "basic $encodedCreds"})}
catch {
        [System.Windows.MessageBox]::Show("Unable connect $ADMINURL : $Error[0]")
        Clear-Variable -Name cred -Scope global
        exit 10
        }


$Global:CLUSTERNAME=$CLUSTER._embedded.clusters.name
$Global:CLUSTERSTATUSURL=$CLUSTER._embedded.clusters._links.self.href
$global:CLUSTERSTATUS=(Invoke-RestMethod -Uri "$ADMINURL$CLUSTERSTATUSURL" -Headers @{Authorization = "basic $encodedCreds"})

$global:SETTINGSURL=$CLUSTERSTATUS._links.'waggle:settings'.href
$global:SETTINGS=(Invoke-RestMethod -Uri "$ADMINURL$SETTINGSURL" -Headers @{Authorization = "basic $encodedCreds"})

$global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Headers @{Authorization = "basic $encodedCreds"})._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
$global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Headers @{Authorization = "basic $encodedCreds"})

$global:NODES=(Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Headers @{Authorization = "basic $encodedCreds"})._embedded.nodes

    $global:CLUSTERSETTINGS=@()
   
    $settings._embedded.settings._links.self.href|%{

    $URL=$_
    $RESULT=(Invoke-RestMethod -Uri "$ADMINURL$URL" -Headers @{Authorization = "basic $encodedCreds"})
    $object = New-Object -TypeName PSObject
            $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $RESULT.name
            $object | Add-Member -Name 'Value' -MemberType Noteproperty -Value $($RESULT.value -join " ")
            $object | Add-Member -Name 'Default' -MemberType Noteproperty -Value $($RESULT.default -join " ")
            $object | Add-Member -Name 'Modified' -MemberType Noteproperty -Value $RESULT.modified
            $object | Add-Member -Name 'Description' -MemberType Noteproperty -Value $RESULT.description
         

            $global:CLUSTERSETTINGS+=$object
    }

            $CLUSTERSETTINGS|Out-GridView -Title "Cluster Parameters" 

     $NODES | % {
            $NODE=$_.id
            $NAME=$_.name
            $global:GATHERERROR=0
            $global:NODESTATUSURL=((Invoke-RestMethod -Uri "$ADMINURL$NODESURL" -Headers @{Authorization = "basic $encodedCreds"})._embedded.nodes._links.self|?{$_.href -like "*nodes/$NODE*"}).href
            try {$global:STATUS=(Invoke-RestMethod -Uri "$ADMINURL$NODESTATUSURL" -Headers @{Authorization = "basic $encodedCreds"} -ErrorAction SilentlyContinue)}
            catch {
            write-host "$NAME is unavailble"
            $global:GATHERERROR=1
            }

            if ( $GATHERERROR -ne 1 ) {
            $HEALTHREPORTURL=$($STATUS._links."waggle:healthreport".href)
            $HEALTHREPORT=(Invoke-RestMethod -Uri "$ADMINURL$HEALTHREPORTURL" -Headers @{Authorization = "basic $encodedCreds"} -TimeoutSec 5)


            $CONFIG=$HEALTHREPORT.healthreport.'SNMP tables'.'Config Variables Table'


            $global:HEALTHCONFIG=@()
            For ($i=0; $i -lt $CONFIG.'1 - Index'.Count; $i++) {
                $object = New-Object -TypeName PSObject
                $object | Add-Member -Name 'Node' -MemberType Noteproperty -Value $Name
                $object | Add-Member -Name 'Source' -MemberType Noteproperty -Value $CONFIG.'5 - Value source'[$i]
                if ( $CONFIG.'4 - Default value'[$i] -eq $CONFIG.'3 - Variable value'[$i] ) { $DIFF = "False" } else { $DIFF = "True" }
                $object | Add-Member -Name 'Modified' -MemberType Noteproperty -Value $DIFF
                $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $CONFIG.'2 - Variable name'[$i]
                $object | Add-Member -Name 'Value' -MemberType Noteproperty -Value $CONFIG.'3 - Variable value'[$i]
                $object | Add-Member -Name 'Default' -MemberType Noteproperty -Value $CONFIG.'4 - Default value'[$i]


                
                $global:HEALTHCONFIG += $object
                }

       
            }
            $HEALTHCONFIG|Out-GridView -Title "$Name parameters" 
}
