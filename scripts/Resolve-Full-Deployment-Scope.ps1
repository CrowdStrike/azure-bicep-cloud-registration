param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
    [string] $AzureTenantId,

    [Parameter(Mandatory = $false)]
    [string[]] $ManagementGroupIds = @(),

    [Parameter(Mandatory = $false)]
    [string[]] $SubscriptionIds = @()
)

try {
    $setInputMamtGroupIds = [System.Collections.Generic.HashSet[string]]::new()
    $totalActiveSubscriptions = [System.Collections.Generic.HashSet[string]]::new()
    $individualActiveSubscriptionIds = [System.Collections.Generic.HashSet[string]]::new()
    $resultMgmtGroupIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($id in $ManagementGroupIds) {
        [void] $setInputMamtGroupIds.Add($id)
    }

    foreach ($id in $SubscriptionIds) {
        [void]$totalActiveSubscriptions.Add($id)
        [void] $individualActiveSubscriptionIds.Add($id)
    }

    # Level order traversal from "Tenant Root Group"
    $curLevel = @(
        @{ parents = @(); value = Get-AzManagementGroup -GroupId $AzureTenantId -Recurse -Expand}
    )
    while($curLevel) {
        $nextLevel = @()
        foreach ($obj in $curLevel) {
            $entry = $obj.value
            $parents = $obj.parents+$entry.Name
            # Only not overlapped groups will be included in the final group list
            if ($setInputMamtGroupIds.Contains($entry.Name) -and !($parents | Where-Object {$resultMgmtGroupIds.Contains($_)})) {
                [void] $resultMgmtGroupIds.Add($entry.Name)
            }
            foreach ($child in $entry.Children) {
                if (($child.Type -eq "/subscriptions") -and ($parents | Where-Object {$setInputMamtGroupIds.Contains($_)})) {
                    [void] $totalActiveSubscriptions.Add($child.Name)
                    [void] $individualActiveSubscriptionIds.Remove($child.Name)
                } elseif ($child.Type -eq "Microsoft.Management/managementGroups") {
                    $nextLevel += @{
                        parents =  $parents
                        value = $child
                    }
                } 
            }
        }
        $curLevel = $nextLevel
    }

    # Filter out disabled subscriptions
    foreach ($subId in $totalActiveSubscriptions) {
        $sub = Get-AzSubscription -SubscriptionId $subId -TenantId $AzureTenantId
        if ($sub.State -ne "Enabled") {
            [void] $totalActiveSubscriptions.Remove($sub.Id)
            [void] $individualActiveSubscriptionIds.Remove($sub.Id)
        }
    }

    $DeploymentScriptOutputs = @{
        'resolvedManagementGroups' = [System.Collections.Generic.List[string]]($resultMgmtGroupIds) # distinct management groups without overlap
        'totalActiveSubscriptions' = [System.Collections.Generic.List[string]]($totalActiveSubscriptions) # total active individual subscriptions covered by specified management groups and subscriptions
        'individualActiveSubscriptionIds' = [System.Collections.Generic.List[string]]($individualActiveSubscriptionIds) # active individual subscriptions not covered by specified management groups
    }
} catch {
    Write-Error "An exception was caught: $($_.Exception.Message)"
    break
}