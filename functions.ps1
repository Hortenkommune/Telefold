function Get-ApplicationAuthToken {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationID,
        [Parameter(Mandatory = $true)]
        [string]$Secret,
        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )

    $TokenEndpoint = "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token"

    $requestBody = @{
        client_id     = $ApplicationID
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $Secret
        grant_type    = "client_credentials"
    }

    $tokenRequest = Invoke-RestMethod -Uri $TokenEndpoint -Method Post -Body $requestBody

    if ($tokenRequest.access_token) {
        $authToken = @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer " + $tokenRequest.access_token
            'ExpiresOn'     = (Get-Date).ToUniversalTime().AddSeconds($tokenRequest.expires_in)
        }
        return $authToken
    }
    else {
        throw "Failed to get authToken"
    }
}