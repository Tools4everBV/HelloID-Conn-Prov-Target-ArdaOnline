############################################
# HelloID-Conn-Prov-Target-ArdaOnline-Enable
# PowerShell V2
# Version: 1.0.0
############################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
function Get-ArdaOnlineAccessTokenAndReturnHttpHeaders {
    param ()
    try {
        $splatTokenParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/auth/oauth2/token/"
            Method  = 'POST'
            Body = @{
                client_id     = $($actionContext.Configuration.ClientID)
                client_secret = $($actionContext.Configuration.ClientSecret)
                username      = $($actionContext.Configuration.UserName)
                password      = $($actionContext.Configuration.Password)
                grant_type    = 'password'
            }
            Headers =  @{
                "content-type" = "application/x-www-form-urlencoded"
            }
        }
        $accessToken = Invoke-RestMethod @splatTokenParams -Verbose:$false
        $headers = [System.Collections.Generic.Dictionary[[String],[String]]]::new()
        $headers.Add("Authorization", "Bearer $($accessToken.access_token)")

        Write-Output $headers
    } catch {
        throw
    }
}

function Get-ArdaOnlineAccount {
    param (
        [string]
        $ExternalUserId,

        [object]
        $Headers
    )

    try {
        $splatGetUserParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/api/graphql/"
            Method      = 'POST'
            Headers     = $Headers
            Body        = @"
            {
               `"query`":`"mutation (`$input: SyncUsersInput!) {syncUsers(input: `$input) {results {user {externalUserId firstName lastName email department locale expiresAt} status errors {path field fieldPrefix message}}}}`",
               `"variables`":{
                  `"input`":{
                     `"users`":[
                        {
                           `"externalUserId`": `"$ExternalUserId`"
                        }
                     ]
                  }
               }
            }
"@
        ContentType = 'application/json'
        }
        $response = Invoke-RestMethod @splatGetUserParams -Verbose:$false
        if(($null -ne $response.data.syncUsers.results.errors) -or ($response.data.syncUsers.results.errors.message -eq 'User does not exist')){
            Write-Output $response.data.syncUsers.results.errors.message
        } else {
            Write-Output $response.data.syncUsers.results.user
        }
    } catch {
        throw
    }
}

function Set-ArdaOnlineAccount {
    param (
        [object]
        $Account,

        [object]
        $Headers
    )

    try {
        $body = @"
{
   `"query`":`"mutation (`$input: SyncUsersInput!) {syncUsers(input: `$input) {results {user {externalUserId firstName lastName email department locale groups vouchers expiresAt} status errors {path field fieldPrefix message}}}}`",
   `"variables`":{
      `"input`":{
         `"users`":[
            $($Account | ConvertTo-Json)
         ]
      }
   }
}

"@
        $splatRestParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/api/graphql/"
            Method      = 'POST'
            Headers     = $Headers
            ContentType = 'application/json'
            Body        = $body
        }
        $response = Invoke-RestMethod @splatRestParams -Verbose:$false
        switch ($response.data.syncUsers.results.status){
            'created' {
                Write-Output $response.data.syncUsers.results.user
            }

            'updated' {
                Write-Output $response.data.syncUsers.results.user
            }

            'failed' {
                $totalErrors = $response.data.syncUsers.results.errors.Length
                for ($i = 0; $i -lt $totalErrors; $i++) {
                    $errorObject = $response.data.syncUsers.results.errors[$i]
                    $customErrorMessage = "Validation failed for field [$($errorObject.field)] with message [$($errorObject.message)]"
                    Write-Warning $customErrorMessage
                }
                throw 'One or more errors occurred when processing the ArdaOnline account. Make sure to check the verbose logging for more details!'
            }
        }
    } catch {
        throw
    }
}


function Resolve-ArdaOnlineError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }

        try {
            $rawErrorResponse = $ErrorObject.ErrorDetails.Message | ConvertFrom-Json
            if ($rawErrorResponse.error){
                $httpErrorObj.ErrorDetails = $rawErrorResponse
                $httpErrorObj.FriendlyMessage = "Message: [$($rawErrorResponse.error_description)], details: [$($rawErrorResponse.error)]"
            } else {
                $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
                $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message
            }
        } catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}
#endregion

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Verbose 'Retrieving AccessToken and create headers'
    $headers = Get-ArdaOnlineAccessTokenAndReturnHttpHeaders

    Write-Verbose "Verifying if a ArdaOnline account for [$($personContext.Person.DisplayName)] exists"
    $correlatedAccount = Get-ArdaOnlineAccount -ExternalUserId $($actionContext.References.Account) -Headers $headers

    if ($actionContext.AccountCorrelated -eq $true -and $null -ne $correlatedAccount) {
        $action = 'EnableAccount'
        $dryRunMessage = "Enable ArdaOnline account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] will be executed during enforcement"
    } else {
        $action = 'NotFound'
        $dryRunMessage = "ArdaOnline account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Verbose -Verbose "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'EnableAccount' {
                Write-Verbose "Enabling ArdaOnline account with accountReference: [$($actionContext.References.Account)]"

                # Add 'externalUserId' and 'email' because both are mandatory
                $account = @{
                    externalUserId = $actionContext.Data.externalUserId
                    email          = $actionContext.Data.email
                    expiresAt      = $actionContext.Data.expiresAt
                }
                $null = Set-ArdaOnlineAccount -Account $account -Headers $headers
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = 'EnableAccount'
                    Message = "Enable account was successful"
                    IsError = $false
                })
                break
            }

            'NotFound' {
                $outputContext.Success  = $false
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Action  = 'EnableAccount'
                    Message = "ArdaOnline account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                    IsError = $true
                })
                break
            }
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ArdaOnlineError -ErrorObject $ex
        $auditMessage = "Could not enable ArdaOnline account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not enable ArdaOnline account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
        Action  = 'EnableAccount'
        Message = $auditMessage
        IsError = $true
    })
}
