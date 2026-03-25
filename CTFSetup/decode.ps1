# Can only be run by "student"

$currentUser = $env:USERNAME

if ($currentUser -ne "student"){
Write-Host -ForegroundColor Red "Access denied."
Start-Sleep -Seconds 5
exit
}

clear-host
$chunks = @(
"c3ZjX2FkbWlu",
"OkNlbnRyaXFD",
"VEZBZG1pblBh",
"c3N3b3JkMSE="
)

$encoded = ($chunks -join "")

$bytes = [System.Convert]::FromBase64String($encoded)
$decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
$credParts = $decoded -split ":"
$un = $credParts[0]
$pw = $credParts[1]

Write-Host -ForegroundColor Green -BackgroundColor Black "Decoded Credentials:"
Write-Host -BackgroundColor Green -ForegroundColor White "Username: $un | Password: $pw"
Pause

$chunks = @(
"c3ZjX2FkbWlu",
"OkNlbnRyaXFD",
"VEZBZG1pblBh",
"c3N3b3JkMSE="
)

$encoded = ($chunks -join "")

$bytes = [System.Convert]::FromBase64String($encoded)
$decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
$credParts = $decoded -split ":"

Write-Host -ForegroundColor Green "Decoded Credentials:"
Write-Host "Username: $(credParts[0]) | Password: $(credParts[1])"
Pause