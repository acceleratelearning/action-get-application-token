#!/usr/bin/env pwsh
param (
    [String] $GitHubAppId = $env:INPUT_GITHUB_APP_ID,
    [String] $GitHubAppKey = $env:INPUT_GITHUB_APP_KEY
)

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name 'hugoalh.GitHubActionsToolkit' -AcceptLicense -Scope CurrentUser
Import-Module -Name 'hugoalh.GitHubActionsToolkit' -Scope 'Local'

function Base64UrlEncodeBytes([Byte[]] $bytes) {
    [Convert]::ToBase64String($bytes) -replace '\+', '-' -replace '/', '_' -replace '='
}
  
function Base64UrlEncodeJson([Object] $object) {
    Base64UrlEncodeBytes([System.Text.Encoding]::UTF8.GetBytes(($object | ConvertTo-Json -Compress)))
}

function Get-GithubAppToken(
    [int] $GitHubAppId,
    [String] $GitHubAppKey,
    [String] $GitHubAppKeyPath
) {
    try {
        # https://docs.github.com/en/developers/apps/building-github-apps/authenticating-with-github-apps
        # https://www.jerriepelser.com/blog/obtain-access-token-github-app-webhook/
        if ($GitHubAppKeyPath) {
            $GitHubAppKey = Get-Content $GitHubAppKeyPath -Raw
        }
        # Remove newline characters and the cert header/footers (-----BEGIN RSA PRIVATE KEY-----)
        $KeyData = ($GitHubAppKey -replace '\n', '') -replace '-+[A-Z ]+-+', ''

        $rsa = [System.Security.Cryptography.RSA]::Create()
        [int]$bytesRead = 0
        $rsa.ImportRSAPrivateKey([Convert]::FromBase64String($KeyData), [ref]$bytesRead)

        $header = Base64UrlEncodeJson(@{alg = 'RS256'; typ = 'JWT' })
        $payload = Base64UrlEncodeJson(@{iat = [DateTimeOffset]::Now.ToUnixTimeSeconds(); exp = [DateTimeOffset]::Now.AddSeconds(600).ToUnixTimeSeconds(); iss = $GitHubAppId })
        $signature = Base64UrlEncodeBytes($rsa.SignData([System.Text.Encoding]::UTF8.GetBytes("$header.$payload"), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1))
        $jwt = "$header.$payload.$signature"

        $headers = @{ Authorization = "Bearer $jwt"; Accept = 'application/vnd.github.machine-man-preview+json' }
        $access_tokens_url = (Invoke-RestMethod -Headers $headers "https://api.github.com/app/installations" -SkipHttpErrorCheck).access_tokens_url
        if (-Not $access_tokens_url) {
            throw "Unable to get GitHub access token url for $GitHubAppId (has GitHubAppKey expired?)"
        }
        $token = (Invoke-RestMethod -Headers $headers -Method Post $access_tokens_url -Verbose:$VerbosePreference).token
        if (-Not $token) {
            throw "Unable to get GitHub access token for $GitHubAppId (has GitHubAppKey expired?)"
        }
        Write-Output $token
    }
    catch {
        Write-Error "GitHubAppId = $GitHubAppId"
        Write-Error "GitHubAppKey = $GitHubAppKey"
        Write-Error $_
        Write-Output ''
    }
}

$token = Get-GithubAppToken -GitHubAppId $GitHubAppId -GitHubAppKey $GitHubAppKey

Set-GitHubActionsOutput "github-app-token" $token