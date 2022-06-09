#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Update
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$pp = $previousPerson | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Account mapping
$account = [PSCustomObject]@{
    UserName = $p.Accounts.MicrosoftAzureADVCZC.UserPrincipalName
    Name     = $p.Accounts.MicrosoftAzureADVCZC.DisplayName # $p.DisplayName
    Email    = $p.Accounts.MicrosoftAzureAD.mail
    Role     = "$($p.PrimaryContract.Title.Code)-$($p.PrimaryContract.Department.ExternalId)"  # This value is used to map title to a Outsystems Role, Which is required for creating a account
}

$previousAccount = [PSCustomObject]@{
    UserName = $pp.Accounts.MicrosoftAzureADVCZC.UserPrincipalName
    Name     = $pp.Accounts.MicrosoftAzureADVCZC.DisplayName # $p.DisplayName
    Email    = $pp.Accounts.MicrosoftAzureAD.mail
    Role     = "" # Is defined later in the script, since this will be queried from the current data in OutSystems
}

# Troubleshooting
# $aRef = "12345678-bf9b-4e2f-9cbc-abcdefghij"
# $account = [PSCustomObject]@{
#     UserName = "TestHelloID@enyoi.onmicrosoft.com"
#     Name     = "Test HelloID"
#     Email    = "TestHelloID@enyoi.onmicrosoft.com"
#     Role     = "Ontwikkelaar"  # This value is used to map title to a Outsystems Role, Which is required for creating a account
# }

# $previousAccount = [PSCustomObject]@{
#     UserName = "TestHelloID@enyoi.onmicrosoft.com"
#     Name     = "Test HelloID"
#     Email    = "TestHelloID@enyoi.onmicrosoft.com"
#     Role     = "Administrator"  # This value is used to map title to a Outsystems Role, Which is required for creating a account
# }
$dryRun = $false

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
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Invoke-CalculateDesiredRole {
    <#
    .DESCRIPTION
        Finds the role which mapped in the configuration and performs a lookup in Outsystems to retrieve the GUID/Key
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $ScriptConfig,

        [parameter()]
        $MappedRole
    )
    try {
        foreach ($role in $ScriptConfig.role.PSObject.Properties) {
            if ($mappedRole -in ($role.Value -split ',' )) {
                $splatWebRequest = @{
                    Uri     = "$($ScriptConfig.BaseUrl)/roles"
                    Headers = $headers
                    Method  = 'GET'
                }
                $roleList = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $roleFound = $roleList.Where( { $_.name -eq $role.name })
                break
            }
        }
        if ($null -eq $roleFound) {
            throw "Unable to find a Role with the mapping specified in the configuration, Function [$($mappedRole)] is not specfied"
        }
        $auditLogs.Add([PSCustomObject]@{
                Message = "Role for Outsystems Account will be set to: $($roleFound.name) ($($roleFound.Key))"
            })
        Write-Output $roleFound
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion

try {
    $headers = New-AuthorizationHeaders -AccessToken $config.Token

    # Set RoleKey for previous account object with RoleKey from current user object
    Write-Verbose 'Retrieve existing account from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($config.BaseUrl)/users/$aref"
        Headers = $headers
        Method  = 'GET'
    }
    $CurrentUser = Invoke-RestMethod @splatWebRequest -Verbose:$false

    $previousAccount.psobject.Properties.Remove("Role")
    $previousAccount | Add-Member -NotePropertyMembers @{ RoleKey = $CurrentUser.RoleKey }

    # Calculate RoleKey for account object
    $roleObject = Invoke-CalculateDesiredRole -ScriptConfig $config -MappedRole $account.Role
    Write-Verbose "Setting role to: $($roleObject.name) ($($roleObject.Key))"
    $account.psobject.Properties.Remove("Role")
    $account | Add-Member -NotePropertyMembers @{ RoleKey = $roleObject.Key }

    # Verify if the account must be updated
    $splatCompareProperties = @{
        ReferenceObject  = @($previousAccount.PSObject.Properties)
        DifferenceObject = @($account.PSObject.Properties)
    }
    $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where( { $_.SideIndicator -eq '=>' })
    if ($propertiesChanged) {
        Write-Verbose "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"
        $action = 'Update'
    } else {
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
                foreach ($property in ($propertiesChanged.where({$_.name -ne 'Role' }))) {
                    $CurrentUser.$($property.name) = $property.value
                }

                Write-Verbose "Updating OutSystems account with accountReference: [$aRef]"
                Write-Verbose "Body: $($CurrentUser | ConvertTo-Json -Depth 10)"
                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users/$aRef"
                    Headers = $headers
                    Method  = 'PUT'
                    Body    = ($CurrentUser | ConvertTo-Json)
                }
                $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $auditLogs.Add([PSCustomObject]@{
                        Action = "UpdateAccount"
                        Message = "Update account was successful for account with accountReference: [$aRef]"
                        IsError = $false
                    })
                break
            }
            'NoChanges' {
                Write-Verbose "No changes to OutSystems account with accountReference: [$aRef]"
                $auditLogs.Add([PSCustomObject]@{
                        Action = "UpdateAccount"
                        Message = 'Update was successful (No Changes needed) for account with accountReference: [$aRef]'
                        IsError = $false
                    })
                break
            }
        }
        $success = $true
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        # $errorObj = Resolve-HTTPError -ErrorObject $ex
        # $errorMessage = "Could not update OutSystems account with accountReference: [$($aRef)]. Error: $($errorObj.ErrorMessage)"
        
        $errorObjectConverted = $_ | ConvertFrom-Json
        $errorMessage = "Could not update OutSystems account with accountReference: [$($aRef)]. Error: $($errorObjectConverted.Errors)"
    } else {
        $errorMessage = "Could not update OutSystems account with accountReference: [$($aRef)]. Error: $($ex.Exception.Message)"
    }

    $verboseErrorMessage = "Could not update OutSystems account with accountReference: [$($aRef)]. Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    Write-Verbose $verboseErrorMessage
  
    $auditLogs.Add([PSCustomObject]@{
            Action = "UpdateAccount"
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Account   = $account
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}