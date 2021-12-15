#####################################################
# HelloID-Conn-Prov-Target-ArdaOnline-Create
#
# Version: 1.0.0
#####################################################
$VerbosePreference = "Continue"

# Initialize default value's
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
$account = @{
    externalUserId = $p.ExternalId
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

    # Verify if a user must be created or correlated
    $splatRestParams = @{
        Uri         = "$($config.BaseUrl)/api/graphql"
        Method      = 'POST'
        Headers     = $Headers
        ContentType = 'application/json'
        Body        = @{
            query = `"mutation (`$input: SyncUsersInput!) {syncUsers(input: `$input) {results {user {externalUserId} errors {path field fieldPrefix message}}}}`"
            variables = @{
                input = @{
                    externalUserId = $($p.ExternalId)
                }
            }
        }
    }
    $responseGetUser = Invoke-RestMethod @splatRestParams
    if (($null -ne $responseGetUser.data.syncUsers.results[0].errors) -and ($responseGetUser.data.syncUsers.results[0].errors[0].message -eq 'User does not exist')){
        $action = 'Create'
    } elseif (($null -ne $responseGetUser.data.syncUsers.results[0].user) -and ($null -ne $responseGetUser.data.syncUsers.results[0].user.externalUserId)){
        $action = 'Correlate'
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true){
        $auditLogs.Add([PSCustomObject]@{
            Message = "$action ArdaOnline account for: [$($p.DisplayName)], will be executed during enforcement"
            IsError = $False
        })
    }

    # Process
    if (-not($dryRun -eq $true)){
        switch ($action) {
            'Create' {
                Write-Verbose "Creating ArdaOnline account for: [$($p.DisplayName)]"
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
                $responseCreateUser = Invoke-RestMethod @splatRestParams
                if ($responseCreateUser.data.syncUsers.results[0].status -eq 'created'){
                    $accountReference = $responseCreateUser.data.syncUsers.results[0].user.externalUserId
                } else {
                    $errorMessage = $responseGetUser.data.syncUsers.results[0].errors[0].message
                    throw $errorMessage
                }
                break

            }

            'Correlate'{
                Write-Verbose "Correlating ArdaOnline account for: [$($p.DisplayName)]"
                $accountReference = $responseGetUser.data.syncUsers.results[0].user.externalUserId
                break
            }
        }

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
            Message = "$action account for: [$($p.DisplayName)] was successful. AccountReference is: [$accountReference]"
            IsError = $false
        })
    }
} catch {
    $success = $false
    $ex = $_
    $errorMessage = "Could not $action ArdaOnline account for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
        Message = $errorMessage
        IsError = $true
    })
# End
} finally {
   $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
