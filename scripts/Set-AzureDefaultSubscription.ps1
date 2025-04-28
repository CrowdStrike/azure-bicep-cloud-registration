## CrowdStrike API Client Scopes required:
## - CSPM Registration (read/write)

param(
    [Parameter(Mandatory = $true)]
    [string]$AzureTenantId,

    [Parameter(Mandatory = $true)]
    [string]$AzureSubscriptionId
)

# Falcon variables
switch ($Env:FALCON_CLOUD_REGION) {
    US-1 {
        $FALCON_API_BASE_URL = "api.crowdstrike.com"
    }
    US-2 {
        $FALCON_API_BASE_URL = "api.us-2.crowdstrike.com"
    }
    EU-1 {
        $FALCON_API_BASE_URL = "api.eu-1.crowdstrike.com"
    } 
    Default {
        $FALCON_API_BASE_URL = "api.crowdstrike.com"
    }
}

# Get CrowdStrike API Access Token
function Get-FalconAPIAccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    try {
        $Params = @{
            Uri     = "https://${FALCON_API_BASE_URL}/oauth2/token"
            Method  = "POST"
            Headers = @{
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            Body    = @{
                client_id     = $ClientId
                client_secret = $ClientSecret
            }
        }
        return ((Invoke-WebRequest @Params).Content | ConvertFrom-Json).access_token
    }
    catch [System.Exception] { 
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

function Set-AzureDefaultSubscription {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$AzureTenantId,

        [Parameter(Mandatory = $true)]
        [string]$AzureSubscriptionId
    )
    try {
        $Params = @{
            Uri     = "https://${FALCON_API_BASE_URL}/cloud-connect-cspm-azure/entities/default-subscription-id/v1?tenant-id=${AzureTenantId}&subscription_id=${AzureSubscriptionId}"
            Method  = "PATCH"
            Headers = @{
                "Authorization" = "Bearer ${AccessToken}"
            }
        }
        return (Invoke-WebRequest @Params).Content
    }
    catch [System.Exception] { 
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

$AccessToken = $(Get-FalconAPIAccessToken -ClientId ${Env:FALCON_CLIENT_ID} -ClientSecret ${Env:FALCON_CLIENT_SECRET})
Set-AzureDefaultSubscription -AccessToken $AccessToken -AzureTenantId $AzureTenantId -AzureSubscriptionId $AzureSubscriptionId