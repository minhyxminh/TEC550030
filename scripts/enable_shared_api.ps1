param(
    [ValidatePattern('^https://[a-zA-Z0-9.-]+(?::[0-9]+)?(?:/[a-zA-Z0-9_/-]+)*$')]
    [string]$ApiBaseUrl = 'https://resjlmqdtxubcbdpvtds.supabase.co/functions/v1/gymflow-api'
)

$ErrorActionPreference = 'Stop'
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

# Do not change Flutter's working local default until the online API works.
try {
    $health = Invoke-RestMethod -Uri "$ApiBaseUrl/health" -TimeoutSec 30
    if ($health.status -ne 'ok' -or $health.database -ne 'connected') {
        throw 'Health response does not confirm the database connection.'
    }
    foreach ($route in @('rewards', 'memberships', 'trainers')) {
        $response = Invoke-WebRequest -Uri "$ApiBaseUrl/$route" -UseBasicParsing -TimeoutSec 30
        if ($response.StatusCode -ne 200 -or -not $response.Content.TrimStart().StartsWith('[')) {
            throw "Invalid catalogue response: $route"
        }
        Write-Output "Verified /$route"
    }
} catch {
    Write-Error ('Shared API is not ready. Deploy gymflow-api, disable platform JWT verification, then retry. Flutter configuration was not changed. ' + $_.Exception.Message)
    exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$targetFile = Join-Path $repoRoot 'tec550030/lib/core/api/shared_api_config.dart'
$content = "// Shared HTTPS API. Public URL only; no keys belong in this file.`nconst defaultApiBaseUrl = '$ApiBaseUrl';`n"
[IO.File]::WriteAllText($targetFile, $content, [Text.UTF8Encoding]::new($false))
Write-Output 'Shared API verified. Flutter now uses HTTPS by default.'
Write-Output 'Commit tec550030/lib/core/api/shared_api_config.dart and share the code.'
Write-Output 'Other members: cd tec550030; flutter pub get; flutter run'
