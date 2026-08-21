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

    Set-AzContext -Subscription $CSInfraSubscriptionId -Tenant $AzureTenantId -ErrorAction Stop

    # Level order traversal from the specified management group
    $curLevel = @(
        Get-AzManagementGroup -GroupId $ManagementGroupId -Recurse -Expand -ErrorAction Stop
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
        $sub = Get-AzSubscription -SubscriptionId $subId -TenantId $AzureTenantId -ErrorAction Stop
        if ($sub.State -ne "Enabled") {
            [void] $activeSubscriptions.Remove($sub.Id)
        }
    }

    $DeploymentScriptOutputs = @{
        'activeSubscriptions' = [System.Collections.Generic.List[string]]($activeSubscriptions)
    }
} catch {
    Write-Error "Failed to resolve subscriptions in management group: $($_.Exception.Message)"
    throw
}