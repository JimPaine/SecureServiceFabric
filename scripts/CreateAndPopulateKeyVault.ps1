param(
    [string]$resourceGroupName,
    [string]$location,
    [string]$vaultName,
    [string]$principalName,
    [string]$password,
    [string]$clusterName,
    [string]$subscriptionId,
    [string]$outFile = "..\templates\azuredeploy.parameters.json"
)

function Create-TestCertificate()
{
    param(
        [string]$subject,
        [string]$friendlyName,
        [string]$password,
        [string]$filePath
    )


    $testCert = New-SelfSignedCertificate -Type Custom -Subject $subject -KeyUsage DigitalSignature -KeyAlgorithm RSA -KeyLength 2048 -CertStoreLocation "Cert:\CurrentUser\My" -FriendlyName $friendlyName -ErrorAction Stop    

    $securePassword = ConvertTo-SecureString -String $password -Force –AsPlainText

    Export-PfxCertificate -cert $testCert -FilePath $filePath -Password $securePassword -ErrorAction Stop

    return $testCert
}

function Create-KeyVault()
{
    param(
        [string]$resourceGroupName,
        [string]$location,
        [string]$vaultName,
        [string]$executingPrincipalName
    )

    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop;
    $vault = New-AzureRmKeyVault -VaultName $vaultName -ResourceGroupName $resourceGroupName -Location $location -Sku standard -ErrorAction Stop;
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -UserPrincipalName $executingPrincipalName -PermissionsToKeys create,import,delete,list -PermissionsToSecrets get, set, delete -ErrorAction Stop;
    Set-AzureRmKeyVaultAccessPolicy -VaultName $vaultName -EnabledForDeployment -EnabledForTemplateDeployment -ErrorAction Stop;
    return $vault;
}

function Add-CertificateToVault()
{
    param(
        [string]$secretName,
        [string]$certLocation,
        [string]$password,
        [string]$vaultName
    )    

    $cert = Get-Content $certLocation -Encoding Byte;
    $cert = [System.Convert]::ToBase64String($cert);

    $json = @"
    {
        "data" : "$cert",
        "dataType": "pfx",
        "password": "$password"
    } 
"@

    $package = [System.Text.Encoding]::UTF8.GetBytes($json);
    $package = [System.Convert]::ToBase64String($package);
    $secret = ConvertTo-SecureString -String $package -AsPlainText -Force;
    return Set-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName -SecretValue $secret -ErrorAction Stop;
}

if ($subscriptionId) {
    Set-AzureRmContext -SubscriptionId $subscriptionId
}

$vault = Create-KeyVault -resourceGroupName $resourceGroupName -location $location -vaultName $vaultName -executingPrincipalName $principalName

$clusterCert = Create-TestCertificate -subject "CN=Cluster Cert" -friendlyName ClusterServerCert -password $password -filePath ClusterServerCert.pfx
$clusterAdminClientCert = Create-TestCertificate -subject "CN=Cluster Admin Client Auth" -friendlyName ClusterAdminClientCert -password $password -filePath ClusterAdminClientCert.pfx 

$clusterSecret = Add-CertificateToVault -secretName clusterCert -certLocation ClusterServerCert.pfx -password $password -vaultName $vaultName
$clusterAdminClientSecret = Add-CertificateToVault -secretName clusterAdminClientCert -certLocation ClusterAdminClientCert.pfx -password $password -vaultName $vaultName

$schema = '$schema'
$parameters = @"
    {
        "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "location" : {
                "value" : "$location",
                "type" : "String"
            },
            "clusterName" : {
                "value" : "$clusterName",
                "type" : "String"
            },
            "adminUsername" : {
                "value" : "",
                "type" : "String"
            },
            "adminPassword" : {
                "value" : "",
                "type" : "String"
            },
            "clusterCertificateThumbPrint" : {
                "value" : "$($clusterCert.ThumbPrint)",
                "type": "String"
            },
            "adminCertificateThumbPrint" : {
                "value" : "$($clusterAdminClientCert.ThumbPrint)",
                "type": "String"
            },
            "sourceVault" : {
                "value" : "$($vault.ResourceId[1])",
                "type": "String"
            },
            "clusterCertificateUrl" : {
                "value" : "$($clusterSecret.Id)",
                "type": "String"
            },
            "adminCertificateUrl" : {
                "value" : "$($clusterAdminClientSecret.Id)",
                "type": "String"
            }
        }
    }
"@

Out-File -FilePath $outFile -InputObject $parameters
return $parameters;
