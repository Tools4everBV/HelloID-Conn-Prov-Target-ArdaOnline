#####################################################
# HelloID-Conn-Prov-Target-ArdaOnline-Delete
# PowerShell V1
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
    expiresAt      = $p.PrimaryContract.EndDate
}

#region functions
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Begin
    Write-Verbose 'Retrieving AccessToken'
    $splatRestParams = @{
        Uri     =  'https://tle-test.thingks.nl/api/auth/oauth2/token/'
        Method  = 'POST'
        Headers =  @{
            "content-type" = "application/x-www-form-urlencoded"
        }
        Body = "client_id=$($config.ClientId)&client_secret=$($config.ClientSecret)&username=$($config.UserName)&password=$($config.Password)&grant_type=password"
    }
    $accessToken = Invoke-RestMethod @splatRestParams

    Write-Verbose 'Adding token to authorization headers'
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $($accessToken.access_token)")

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true){
        $auditLogs.Add([PSCustomObject]@{
            Message = "Delete ArdaOnline account for: [$($p.DisplayName)], will be executed during enforcement"
            IsError = $False
        })
    }

    # Process
    if (-not($dryRun -eq $true)){
        Write-Verbose "Deleting ArdaOnline account for: [$($p.DisplayName)]"
        $splatRestParams = @{
            Uri         = "$($config.BaseUrl)/api/graphql"
            Method      = 'POST'
            Headers     = $headers
            ContentType = 'application/json'
            Body        = @{
                query = "mutation (`$input: SyncUsersInput!) {syncUsers(input: `$input) {results {user {externalUserId expiresAt} status errors {path field fieldPrefix message}}}}"
                variables = @{
                    input = @{
                        users = @($account)
                    }
                }
            } | ConvertTo-Json -Depth 10
        }
        $responseDeleteUser = Invoke-RestMethod @splatRestParams
        if ($responseDeleteUser.data.syncUsers.results.count -ge 1){
            if ($responseDeleteUser.data.syncUsers.results[0].status -eq 'deactivated'){
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                    Message = "Delete account for: [$($p.DisplayName)] was successful."
                    IsError = $false
                })
            } elseif ($null -ne $responseDeleteUser.data.syncUsers.results[0].errors) {
                $errorMessage = $responseDeleteUser.data.syncUsers.results[0].errors[0].message
                throw $errorMessage
            }
        }
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
    $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-HTTPError -ErrorObject $ex
        $errorMessage = "Could not delete ArdaOnline account for: [$($p.DisplayName)]. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not delete ArdaOnline account for: [$($p.DisplayName)]. Error: $($ex.Exception.Message)"
    }
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
