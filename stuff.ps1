function Test-AuthToken {
    param(
        $authToken
    )

    if ($authToken -eq $null) {
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
    return $Output
}

function Get-TeamMembers {
    param(
        $aadGroupID,
        $authToken
    )
    $users = Get-GraphData -uri "https://graph.microsoft.com/beta/groups/$aadGroupID/members" -authToken $authToken
    return $users
}

function Get-TeamOwners {
    param(
        $aadGroupID,
        $authToken
    )
    $owners = Get-GraphData -uri "https://graph.microsoft.com/beta/groups/$aadGroupID/owners" -authToken $authToken
    return $owners
}

function Get-AADUserFromMail {
    param(
        $mail,
        $authToken
    )
    $user = Get-GraphData -uri "https://graph.microsoft.com/beta/users?`$filter=mail eq '$mail'" -authToken $authToken
    return $user
}

function Add-TeamMember {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $body = @{"@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$userId" } | ConvertTo-Json
    $result = Invoke-RestMethod -Method Post -Uri " https://graph.microsoft.com/beta/groups/$groupId/members/`$ref" -Body $body -Headers $authToken
    return $result
}

function Add-TeamOwner {
    param(
        $userId,
        $groupId,
        $authToken
    )
    $body = @{"@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$userId" } | ConvertTo-Json
    $result = Invoke-RestMethod -Method Post -Uri " https://graph.microsoft.com/beta/groups/$groupId/owners/`$ref" -Body $body -Headers $authToken
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

function New-AADUser {
    param (
        $Username,
        $FirstName,
        $LastName,
        $authToken
    )
    $mailnickname = ($Username -split "@")[0]
    $body = New-Object psobject -Property @{
        accountEnabled    = $true
        displayName       = $FirstName + " " + $LastName
        givenName         = $FirstName
        surname           = $LastName
        mailNickname      = $mailnickname
        userPrincipalName = $Username
        passwordProfile   = New-Object psobject -Property @{
            forceChangePasswordNextSignIn = $true
            password                      = ######
        }
    }
    $json = ($body | ConvertTo-Json)
    $utf8json = ([System.Text.Encoding]::UTF8.GetBytes($json))
    #$resp = $utf8json
    #$resp = $json
    $resp = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/users" -Method Post -Body $utf8json -Headers $authToken
    return $resp
}

function Remove-AADUser {
    param (
        $aadObjId,
        $authToken
    )
    $resp = Invoke-RestMethod -Uri "https://graph.microsoft.com/beta/users/$aadObjId" -Method Delete -Headers $authToken
    return $resp
}