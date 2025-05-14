param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
    [string] $AzureTenantId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
    [string] $CSInfraSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $ManagementGroupId
)

try {
    $activeSubscriptions = [System.Collections.Generic.HashSet[string]]::new()

    Set-AzContext -Subscription $CSInfraSubscriptionId -Tenant $AzureTenantId

    # Level order traversal from the specified management group
    $curLevel = @(
        Get-AzManagementGroup -GroupId $ManagementGroupId -Recurse -Expand
    )
    while($curLevel) {
        $nextLevel = @()
        foreach ($entry in $curLevel) {
            foreach ($child in $entry.Children) {
                if ($child.Type -eq "/subscriptions") {
                    [void] $activeSubscriptions.Add($child.Name)
                } elseif ($child.Type -eq "Microsoft.Management/managementGroups") {
                    $nextLevel += $child
                } 
            }
        }
        $curLevel = $nextLevel
    }

    # Filter out disabled subscriptions
    foreach ($subId in $activeSubscriptions) {
        $sub = Get-AzSubscription -SubscriptionId $subId -TenantId $AzureTenantId
        if ($sub.State -ne "Enabled") {
            [void] $activeSubscriptions.Remove($sub.Id)
        }
    }

    $DeploymentScriptOutputs = @{
        'activeSubscriptions' = [System.Collections.Generic.List[string]]($activeSubscriptions)
    }
} catch {
    Write-Error "An exception was caught: $($_.Exception.Message)"
    break
}