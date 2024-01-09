############################################
# HelloID-Conn-Prov-Target-ArdaOnline-Create
# PowerShell V2 connector
# Version: 1.0.0
############################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($actionContext.Configuration.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#Region functions
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
#EndRegion functions

# Begin
try {
    Write-Verbose 'Retrieving AccessToken and create headers'
    $headers = Get-ArdaOnlineAccessTokenAndReturnHttpHeaders

    # Verify if a user must be either [created and correlated], [updated] or just [correlated]
    if ($actionContext.CorrelationConfiguration.Enabled -eq $true){
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Mandatory attribute [externalUserId] is empty. Please make sure it is correctly mapped'
        }

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
    } else {
        throw 'Correlation is not setup correctly. Please make sure to correctly configure correlation on the [Correlation] tab within HelloID'
    }

    $correlatedAccount = Get-ArdaOnlineAccount -ExternalUserId $correlationValue -Headers $headers
    if ($correlatedAccount -eq 'User does not exist'){
        $action = 'CreateAccount'
        $outputContext.AccountReference = 'Currently not available'
    } else {
        $action = 'CorrelateAccount'
        $outputContext.AccountReference = $correlatedAccount.externalUserId
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Verbose "[DryRun] $action ArdaOnline account for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'CreateAccount' {
                Write-Verbose 'Creating and correlating ArdaOnline account'
                $response = Set-ArdaOnlineAccount -Account $($actionContext.Data) -Headers $headers
                $outputContext.AccountReference = $response.externalUserId
                $outputContext.AccountCorrelated = $true
                $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)"
                break
            }

            'CorrelateAccount' {
                Write-Verbose 'Correlating ArdaOnline account'
                $outputContext.AccountReference = $correlatedAccount.externalUserId
                $outputContext.AccountCorrelated = $true
                $auditLogMessage = "Correlated account: [$($correlatedAccount.externalUserId)] on field: [$($correlationField)] with value: [$($correlationValue)]"
                break
            }
        }

        $outputContext.success = $true
        $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-ArdaOnlineError -ErrorObject $ex
        $auditMessage = "Could not $action ArdaOnline account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not $action ArdaOnline account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditMessage
            IsError = $true
        })
}
