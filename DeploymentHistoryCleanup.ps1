Param
(    
    [Parameter (Mandatory= $true)]
    [int] $RetentionDays = 3
)

# Add your Azure account to the local PowerShell environment.
$connectionName = "AzureRunAsConnection"

$SubscriptionName = Get-AutomationVariable -Name "SubscriptionName"
$ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName"

try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    
    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    
    "Setting context to a specific subscription"
    Set-AzureRmContext -SubscriptionName $SubscriptionName
} catch {
    if (!$servicePrincipalConnection) {
       $ErrorMessage = "Connection $connectionName not found."
       throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$deployments = Get-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName

$deploymentsToDelete = $deployments | where { $_.Timestamp -lt ((get-date).AddDays(-1 * $RetentionDays)) }

Write-Output "$($deploymentsToDelete.Count) deployments to delete"

foreach ($deployment in $deploymentsToDelete) {
    Write-Output "Deleting $($deployment.DeploymentName) [$($deployment.Timestamp)] ..."
    Remove-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -DeploymentName $deployment.DeploymentName -Force
}