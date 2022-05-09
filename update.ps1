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

# Account mapping
$account = [PSCustomObject]@{
    UserName = $p.Accounts.MicrosoftActiveDirectory.mail
    Name     = $p.DisplayName
    Email    = $p.Accounts.MicrosoftActiveDirectory.mail
    Role     = $p.PrimaryContract.Title.code  # This value is used to map title to a Outsystems Role, Which is required for creating a account
}

$previousAccount = [PSCustomObject]@{
    UserName = $pp.Accounts.MicrosoftActiveDirectory.mail
    Name     = $pp.DisplayName
    Email    = $pp.Accounts.MicrosoftActiveDirectory.mail
    Role     = $pp.PrimaryContract.Title.code  # This value is used to map title to a Outsystems Role, Which is required for creating a account
}

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
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
        Look up the desired role that is mapped in the configuration based on a comma-separated string of function codes.
        Performs a lookup in Outsystems to get the GUID/Key
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        $ScriptConfig,

        [parameter()]
        $MappedRole
    )
    try {
        # A complex way to look up the desired role from the config. and get the GUID of the specific role
        foreach ($role in $ScriptConfig.role.PSObject.Properties) {
            if ($Role -in ($mappedRole.value -split ',' )) {
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
                Message = "Role [$($roleFound.name)] will be added to Outsystems Account"
            })
        Write-Output $roleFound.key
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion

try {
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
                $headers = New-AuthorizationHeaders -AccessToken $config.Token

                Write-Verbose 'Retrieve existing account from OutSystems'
                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users/$aref"
                    Headers = $headers
                    Method  = 'GET'
                }
                $CurrentUser = Invoke-RestMethod @splatWebRequest -Verbose:$false

                if ($propertiesChanged.name -eq 'Role') { #
                    $guid = Invoke-CalculateDesiredRole -ScriptConfig $config -MappedRole $account.Role
                    $Account.PSObject.Properties.Remove('Role')
                    $CurrentUser.RoleKey = $guid
                }

                foreach ($property in ($propertiesChanged.where({$_.name -ne 'Role' }))) {
                    $CurrentUser.$($property.name) = $property.value
                }

                Write-Verbose "Updating OutSystems account with accountReference: [$aRef]"
                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users/$aRef"
                    Headers = $headers
                    Method  = 'PUT'
                    Body    = ($CurrentUser | ConvertTo-Json)
                }
                $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'Update account was successful'
                        IsError = $false
                    })
                break
            }
            'NoChanges' {
                Write-Verbose "No changes to OutSystems account with accountReference: [$aRef]"
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'Update account was successful (No Changes needed)'
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
        $errorObj = Resolve-HTTPError -ErrorObject $ex
        $errorMessage = "Could not update OutSystems account. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not update OutSystems account. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
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
