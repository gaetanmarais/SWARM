#import-module awspowershell.netcore -Cmdlet get-s3bucket,get-s3object,get-s3presignedurl
import-module AWS.Tools.Installer


$ENDPOINT="https://production.swarm.datacore.paris"
$BUCKET="public"
$RETENTION="1"
$MODE="GOVERNANCE"


try { $RESULT=Get-S3BucketVersioning -EndpointUrl $ENDPOINT -BucketName $BUCKET}
catch {
    write-host "The bucket $BUCKET is not available on domain $ENDPOINT"
    break
    }

#check if Versioning is enabled
if ( $RESULT.status.value -ne "Enabled" ) {
    write-host "Bucket $BUCKET have no versioning enabled"
    break 
}

#check if S3locking is enable 
try {$RESULT=Get-S3ObjectLockConfiguration -BucketName $BUCKET  -EndpointUrl $ENDPOINT }
catch {
    write-host "no lock configured for bucket $BUCKET"
    break
}



Get-S3Object -BucketName $BUCKET -EndpointUrl $ENDPOINT | % {

$KEY=$_.key

$METADATA=(Get-S3ObjectMetadata  -BucketName $BUCKET -EndpointUrl $ENDPOINT -Key $KEY)

if ( ! $METADATA.ObjectLockMode ) { 
        write-host "$KEY not protected"
        Write-S3ObjectRetention -BucketName $BUCKET -EndpointUrl $ENDPOINT -Key $KEY -Retention_Mode $MODE -Retention_RetainUntilDate $((get-date).AddDays($RETENTION)) 
    }
else { 
        write-host "$KEY is protected till $($METADATA.ObjectLockRetainUntilDate)" 
        #Write-S3ObjectRetention -BucketName $BUCKET -EndpointUrl $ENDPOINT -Key $KEY -Retention_Mode $MODE -Retention_RetainUntilDate $((get-date).AddDays($RETENTION)) 
    }
}