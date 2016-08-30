Helpers and an ARM template for a X509 secured cluster
======================================================

### PowerShell Script

This [PowerShell script](scripts/CreateAndPopulateKeyVault.ps1) is aimed to assist in the creation of test certificates, creation of an Azure Key Vault, adding 
the certificates as secrets into the Key Vault and then generating a parameters.json file to accompany the ARM template. The certificates will also be installed 
into the local user certificate store as this is required for accessing the explorer.

To use the script browse to the location of the .ps1 file and execute the following where the 
parameters are: 

| Parameter          | Example       | Comment                                                                                                                 |
| ------------------ |:-------------:| -----------------------------------------------------------------------------------------------------------------------:|
| resourceGroupName  | secureCluster | The resource group you would like the key vault and cluster                                                             |
| location           | "west europe" | The Azure region to create the resource group                                                                           |
| vaultName          | keyVault123   | The vaultName is used within the FQDN so has to be unique                                                               |
| principalName      | me@myorg.com  | The principal running the script. Used to set their permissions on the key vault, allowing them to add the certificates |
| password           | Password1     | The password in plain text, as the value added to the vault for the ARM template doesn't work with a secure string      |
| clusterName        | securecluster | The name of your new cluster, only needed to help generate the parameters.json file                                     |


```powershell
> .\CreateAndPopulateKeyVault.ps1 -resourceGroupName secureCluster -location "west europe" -vaultName keyVault123 -principalName me@myorg.com -password Password1 -clusterName securecluster
```

This will then generate your parameters file which will contains the URLs of the certificates and the Id of the key vault. You will need to update it to include 
the username and password you wish you use for the VM Scale Set.

### ARM Template

Once you are happy with the parameters file you can then deploy the ARM template, by browsing to the ARM template and executing the following in PowerShell.

```powershell
> Login-AzureRmAccount
> New-AzureRmResourceGroupDeployment -name firstDeploy -resourceGroupName secureCluster -templateFile .\azuredeploy.json -templateParameterFile .\azuredeploy.parameters.json
```

### Application deployment steps

Coming soon ...
