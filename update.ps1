#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Update
#
# Version: 1.0.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Account mapping
$account = [PSCustomObject]@{
    UserName = $p.Accounts.MicrosoftActiveDirectory.UserPrincipalName
    Name     = $p.Accounts.MicrosoftActiveDirectory.DisplayName # $p.DisplayName
    Email    = $p.Accounts.MicrosoftActiveDirectory.mail
}

# Troubleshooting
# $aRef = @{
#     Username = "TestHelloID@enyoi.onmicrosoft.com"
#     id = "12345678-bf9b-4e2f-9cbc-abcdefghij"
# }
# $account = [PSCustomObject]@{
#     UserName = "TestHelloID@enyoi.onmicrosoft.com"
#     Name     = "Test HelloID"
#     Email    = "TestHelloID@enyoi.onmicrosoft.com"
# }

# $dryRun = $false

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
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}
function New-AuthorizationHeaders {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.Dictionary[[String], [String]]])]
    param(
        [parameter(Mandatory)]
        [string]
        $AccessToken
    )
    try {
        Write-Verbose 'Adding Authorization headers'
        $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
        $headers.Add('Authorization', "Bearer $($AccessToken)")
        $headers.Add('Accept', 'application/json')
        $headers.Add('Content-Type', 'application/json')
        Write-Output $headers
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion

try {
    if ($null -eq $aRef.id) {
        throw "No Account Reference found in HelloID"
    }

    $headers = New-AuthorizationHeaders -AccessToken $c.Token

    # Get all roles and group by key
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/roles"
        Headers = $headers
        Method  = 'GET'
    }
    $roleList = Invoke-RestMethod @splatWebRequest -Verbose:$false
    $roleListGrouped = $roleList | Group-Object -Property Key -AsHashTable -AsString

    Write-Verbose 'Retrieve Account list from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/users?IncludeInactive=true"
        Headers = $headers
        Method  = 'GET'
    }
    $userList = Invoke-RestMethod @splatWebRequest -Verbose:$false

    Write-Verbose "Account lookup based on UserName [$($account.UserName)]"
    $CurrentUser = $userList | Where-Object { $_.Username -eq $account.UserName }

    # Verify if the account must be updated
    $splatCompareProperties = @{
        ReferenceObject  = @($CurrentUser.PSObject.Properties)
        DifferenceObject = @($account.PSObject.Properties)
    }
    $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where( { $_.SideIndicator -eq '=>' })
    if ($propertiesChanged) {
        Write-Verbose "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"
        $action = 'Update'
    }
    else {
        $action = 'NoChanges'
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Update OutSystems account for: [$($p.DisplayName)] will be executed during enforcement"
            })
    }

    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Update' {
                foreach ($property in ($propertiesChanged.where({ $_.name -ne 'Role' }))) {
                    $CurrentUser.$($property.name) = $property.value
                }

                $body = ($CurrentUser | ConvertTo-Json)
                Write-Verbose "Updating OutSystems account $($aref.username) ($($aRef.id))"
                Write-Verbose "Body: $body"
                $splatWebRequest = @{
                    Uri     = "$($c.BaseUrl)/users/$aRef.id"
                    Headers = $headers
                    Method  = 'PUT'
                    Body    = ([System.Text.Encoding]::UTF8.GetBytes($body)) 
                }
                $updatedUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $aRef = [PSCustomObject]@{
                    id       = $updatedUser.key
                    username = $updatedUser.username
                }
                $roleName = $roleListGrouped["$($updatedUser.RoleKey)"].Name

                $auditLogs.Add([PSCustomObject]@{
                        Action  = "UpdateAccount"
                        Message = "Update account was successful for account $($aref.username) ($($aRef.id))"
                        IsError = $false
                    })
                break
            }
            'NoChanges' {
                Write-Verbose "No changes to OutSystems account $($aref.username) ($($aRef.id))"
                $roleName = $roleListGrouped["$($CurrentUser.RoleKey)"].Name
                
                $auditLogs.Add([PSCustomObject]@{
                        Action  = "UpdateAccount"
                        Message = "Update was successful (No Changes needed) for account $($aref.username) ($($aRef.id))"
                        IsError = $false
                    })
                break
            }
        }
        $success = $true
    }
}
catch {
    $ex = $PSItem

    # Define (general) action message
    $actionMessage = "Could not update OutSystems account $($aref.username) ($($aRef.id))"

    # Define verbose error message, including linenumber and line and full error message
    $verboseErrorMessage = "$($actionMessage). Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    Write-Verbose $verboseErrorMessage

    # Define audit message, consisting of actual error only
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        try {

            $errorObject = $ex | ConvertFrom-Json
            if ($null -ne $errorObject) {
                $auditErrorMessage = $errorObject.Errors
            }
        }
        catch {
            $auditErrorMessage = "$($ex.Exception.Message)"
        }
    }
    else {
        $auditErrorMessage = "$($ex.Exception.Message)"
    }

    # Log error to HelloID
    $success = $false
    $auditLogs.Add([PSCustomObject]@{
            Action  = "UpdateAccount"
            Message = "$($actionMessage). Error: $auditErrorMessage"
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success    = $success
        Account    = $account
        Auditlogs  = $auditLogs

        # Optionally return data for use in other systems
        ExportData = [PSCustomObject]@{
            id       = $aRef.id;
            username = $aRef.username;
            role     = $roleName;
        }
    }; 
    Write-Output $result | ConvertTo-Json -Depth 10
}