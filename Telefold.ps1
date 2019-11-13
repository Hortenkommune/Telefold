. .\functions.ps1

#AuthToken
$appAuthToken = Get-ApplicationAuthToken -ApplicationID $Config.ApplicationID -Secret $Config.Secret -TenantName $Config.TenantName


#Invoke-RestMethod vs Get-GraphData
$allIntuneDevices = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices" -Headers $appAuthToken
$allIntuneDevices = Get-GraphData -uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices" -authToken $appAuthToken

#Hente info i fra Education API (Grupper opprettet fra School Data Sync)
$schools = Get-GraphData -uri "https://graph.microsoft.com/beta/education/schools" -authToken $appAuthToken
$membersOfalphaskl = Get-GraphData -uri "https://graph.microsoft.com/beta/education/schools/60fbde2d-a367-4854-b890-63893449c03e/users" -authToken $appAuthToken
$membersOfalphaskl = Get-GraphData -uri "https://graph.microsoft.com/beta/education/schools/60fbde2d-a367-4854-b890-63893449c03e/users?`$select=id,displayName,userPrincipalName,primaryRole" -authToken $appAuthToken

#Wipe devicer i Intune
$studentsOfalphaskl = Get-GraphData -uri "https://graph.microsoft.com/beta/education/schools/60fbde2d-a367-4854-b890-63893449c03e/users?`$filter=primaryRole eq 'student'&`$select=id,displayName,userPrincipalName,primaryRole" -authToken $appAuthToken
foreach ($student in $studentsOfalphaskl) {
    $devices = Get-GraphData -uri "https://graph.microsoft.com/beta/users/$($student.id)/managedDevices?`$select=id,deviceName" -authToken $appAuthToken
    Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($devices[1].id)/wipe" -Headers $appAuthToken
}


#Håndtere medlemmer i Teams
$groupID = "a709d725-19f0-44cc-9a19-423144c0e90e"
$ownersQ = Get-Content owners
$membersQ = Get-Content members

$ownersNow = Get-TeamOwners -aadGroupID $groupID -authToken $appAuthToken
$membersNow = Get-TeamMembers -aadGroupID $groupID -authToken $appAuthToken

$ownersToRemove = $ownersNow | Where-Object { $_.userPrincipalName -notin $ownersQ }
foreach ($owner in $ownersToRemove) {
    Remove-TeamOwner -userId $owner.id -groupId $groupID -authToken $appAuthToken
}

$membersToRemove = $membersNow | Where-Object { $_.userPrincipalName -notin $membersQ }
foreach ($member in $membersToRemove) {
    Remove-TeamMember -userId $member.id -groupId $groupID -authToken $appAuthToken
}

$ownersToAdd = $ownersQ | Where-Object { $_ -notin $ownersNow.userPrincipalName }
foreach ($owner in $ownersToAdd) {
    $aadObj = Get-AADUserFromMail -mail $owner -authToken $appAuthToken
    Add-TeamOwner -userId $aadObj.id -groupId $groupID -authToken $appAuthToken
}

$membersToAdd = $membersQ | Where-Object { $_ -notin $membersNow.userPrincipalName }
foreach ($member in $membersToAdd) {
    $aadObj = Get-AADUserFromMail -mail $member -authToken $appAuthToken
    Add-TeamMember -userId $aadObj.id -groupId $groupID -authToken $appAuthToken
}