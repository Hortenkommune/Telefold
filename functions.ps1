$Global:Config = Get-Content config.json | ConvertFrom-Json

function New-Config {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationID,
        [Parameter(Mandatory = $true)]
        [string]$Secret,
        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )

    $Object = [PSCustomObject]@{
        ApplicationID = $ApplicationID
        Secret        = $Secret
        TenantName    = $TenantName
    }
    $Object | ConvertTo-Json | Out-File config.json
}

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
            'ExpiresOn'     = (Get-Date).AddSeconds($tokenRequest.expires_in).ToUniversalTime()
        }
        return $authToken
    }
    else {
        throw "Failed to get authToken"
    }
}

function Test-AuthToken {
    Param(
        $authToken
    )

    if (!($authToken)) {
        $authToken = Get-AuthToken
    }
    else {
        $DateTime = (Get-Date).ToUniversalTime()
        $TokenExpires = ($authToken.ExpiresOn - $DateTime).Minutes
        if ($TokenExpires -le 1) {
            $authToken = Get-AuthToken
        }
    }
    return $authToken
}

function Get-GraphData {
    Param (
        $uri,
        $authToken
    )
    $Response = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get)
    $Output = $Response.Value
    $NextLink = $Response."@odata.nextLink"

    while ($NextLink -ne $null) {
        $Response = (Invoke-RestMethod -Uri $NextLink -Headers $authToken -Method Get)
        $NextLink = $Response."@odata.nextLink"
        $Output += $Response.Value
    }
    if (!($Output)) {
        $Output = $Response
    }
    return $Output
}

function Get-AADUserFromMail {
    param(
        $mail,
        $authToken
    )
    $user = Get-GraphData -uri "https://graph.microsoft.com/beta/users?`$filter=mail eq '$mail'" -authToken $authToken
    return $user
}

function Get-TeamOwners {
    param(
        $aadGroupID,
        $authToken
    )
    $owners = Get-GraphData -uri "https://graph.microsoft.com/beta/groups/$aadGroupID/owners" -authToken $authToken
    return $owners
}

function Get-TeamMembers {
    param(
        $aadGroupID,
        $authToken
    )
    $users = Get-GraphData -uri "https://graph.microsoft.com/beta/groups/$aadGroupID/members" -authToken $authToken
    return $users
}

function Add-TeamMember {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $body = @{"@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$userId" } | ConvertTo-Json
    $result = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/groups/$groupId/members/`$ref" -Body $body -Headers $authToken
    return $result
}

function Add-TeamOwner {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $body = @{"@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$userId" } | ConvertTo-Json
    $result = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/groups/$groupId/owners/`$ref" -Body $body -Headers $authToken
    return $result
}

function Remove-TeamMember {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $result = Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/groups/$groupId/members/$userId/`$ref" -Headers $authToken
    return $result
}

function Remove-TeamOwner {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $result = Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/groups/$groupId/owners/$userId/`$ref" -Headers $authToken
    return $result
}