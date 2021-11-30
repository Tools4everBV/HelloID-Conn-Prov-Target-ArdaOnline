#####################################################
# HelloID-Conn-Prov-Target-ArdaOnline-Update
#
# Version: 1.0.0
#####################################################
$VerbosePreference = "Continue"

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = New-Object Collections.Generic.List[PSCustomObject]

# Account mapping
$account = @{
    externalUserId = $aRef
    firstName      = $p.Name.GivenName
    lastName       = $p.Name.FamilyName
    department     = $p.PrimaryContract.Department
    locale         = 'nl'
    groups         = @($($config.GroupId))
    vouchers       = @($($config.VoucherCode))
    email          = $p.contact.Business.Email
    expiresAt      = $p.PrimaryContract.EndDate
}

try {
    # Begin
    Write-Verbose 'Retrieving AccessToken'
    $splatRestParams = @{
        Uri     = "$($config.BaseUrl)/api/auth/oauth2/token?grant_type=password&client_id=$($config.ClientID)&client_secret=$($config.ClientSecret)&username=$($config.UserName)&password=$($config.Password)"
        Method  = 'POST'
        Headers =  @{
            "content-type" = "application/x-www-form-urlencoded"
        }
    }
    $accessToken = Invoke-RestMethod @splatRestParams

    Write-Verbose 'Adding token to authorization headers'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Token $($accessToken.access_token)")

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true){
        $auditLogs.Add([PSCustomObject]@{
            Message = "Update ArdaOnline account for: [$($p.DisplayName)], will be executed during enforcement"
            IsError = $False
        })
    }

    # Process
    if (-not($dryRun -eq $true)){
        Write-Verbose "Updating ArdaOnline account for: [$($p.DisplayName)]"
        $splatRestParams = @{
            Uri         = "$($config.BaseUrl)/api/graphql"
            Method      = 'POST'
            Headers     = $Headers
            ContentType = 'application/json'
            Body        = @{
                query = "mutation (`$input: SyncUsersInput!) {syncUsers(input: `$input) {results {user {externalUserId firstName lastName email department locale groups vouchers expiresAt} status errors {path field fieldPrefix message}}}}"
                variables = @{
                    input = @{
                        users = @($account)
                    }
                }
            } | ConvertTo-Json -Depth 10
        }
        $responseUpdateUser = Invoke-RestMethod @splatRestParams
        if ($responseUpdateUser.data.syncUsers.results[0].status -eq 'updated'){
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                Message = "Update account for: [$($p.DisplayName)] was successful."
                IsError = $false
            })
        } else {
            $errorMessage = $responseUpdateUser.data.syncUsers.results[0].errors[0].message
            throw $errorMessage
        }
    }
} catch {
    $success = $false
    $ex = $_
    $errorMessage = "Could not update ArdaOnline account for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
        Message = $errorMessage
        IsError = $true
    })
# End
} finally {
    $result = [PSCustomObject]@{
        Success      = $success
        Account      = $account
        Auditlogs    = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
