#import-module awspowershell.netcore -Cmdlet get-s3bucket,get-s3object,get-s3presignedurl
#import-module AWS.Tools.Installer -Cmdlet get-s3bucket,get-s3object,get-s3presignedurl
import-module AWSPowerShell.NetCore


# TLS12 security protocol
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


$ENDPOINT="https://production.swarm.datacore.paris"

$NEWENDPOINT= Read-Host "Enter your Endpoint [https://production.swarm.datacore.paris]"

if ( "$NEWENDPOINT"  -ne "" ) { $ENDPOINT=$NEWENDPOINT}

if ( $ENDPOINT -notlike "https://*") { $ENDPOINT="https://"+$ENDPOINT}


$SHARETABLE=@()


$BUCKET=((Get-S3Bucket -EndpointUrl $ENDPOINT | select BucketName |Sort-Object  -Property BucketName | ? {$_.BucketName -notlike ".*"})  | Out-GridView  -Title "Select the bucket" -PassThru  )
$BUCKET=

Get-S3object -BucketName $BUCKET.BucketName -EndpointUrl $ENDPOINT | select Key,LastModified,Etag  | Out-GridView -Title "Select objects to share" -PassThru  | % {
          
    $OBJECT=$_.key
    
    #$SHARELINK=Get-S3PreSignedURL -BucketName $BUCKET.BucketName -EndpointUrl $ENDPOINT -Expire 624960 $OBJECT 

    $SHARELINK=& "C:\program files\Amazon\AWSCLIV2\aws.exe" s3 --endpoint $ENDPOINT presign s3://$($BUCKET.BucketName)/$OBJECT --expires-in 604800 


    set-clipboard -Value $SHARELINK

    $OBJ = New-Object Psobject
    $OBJ | Add-Member -Name "Object"       -membertype Noteproperty -Value $OBJECT
    $OBJ | Add-Member -Name "ShareLink"    -membertype Noteproperty -Value $SHARELINK
    $SHARETABLE += $OBJ
    
}

$SHARETABLE | out-gridview -title "Object share links..." -wait