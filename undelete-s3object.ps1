
import-module AWSPowerShell.NetCore


$ENDPOINT="https://production.swarm.datacore.paris"
$BUCKET="s3lock"



(Get-S3Version -EndpointUrl $ENDPOINT -BucketName $BUCKET).versions | Select-Object isdeletemarker,key,etag,versionid,islatest,size| sort -Descending IsDeleteMarker,Key | Out-GridView -PassThru | % {

$KEY=$_.key
$VERSIONID=$_.VersionId
$ISDELETED=$_.isdeletemarker
}

try {(Get-S3ObjectMetadata -EndpointUrl $ENDPOINT -BucketName $BUCKET -Key $KEY -VersionId $VERSIONID)| Select-Object etag,ObjectLockMode,ObjectLockLegalHoldStatus,ObjectLockRetainUntilDate | Out-GridView}
catch { 
    if ( $ISDELETED = "True" ) {

        $RESULT=Remove-S3Object -EndpointUrl $ENDPOINT -BucketName $BUCKET -Key $KEY -VersionId $VERSIONID -Force
        write-host "Delete marker for $KEY has been removed"
        pause
    }
    else { write-host "Something goes wrong"}

}
