#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Set to true if accounts in the target system must be updated
$updateAccount = $true

#region helper functions
function Get-ComplexRandomPassword{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Length,
        [Parameter(Mandatory=$true)]
        $NonAlphaChars
    )
    
    $password = [System.Web.Security.Membership]::GeneratePassword($Length, $NonAlphaChars);
    
    return $password;
}
#endregion helper functions

# Account mapping
$account = [PSCustomObject]@{
    UserName = $p.Accounts.MicrosoftAzureADVCZC.UserPrincipalName
    Name     = $p.Accounts.MicrosoftAzureADVCZC.DisplayName # $p.DisplayName
    IsActive = $false
    Email    = $p.Accounts.MicrosoftAzureAD.mail
    Role     = "$($p.PrimaryContract.Title.Code)-$($p.PrimaryContract.Department.ExternalId)"  # This value is used to map title to a Outsystems Role, Which is required for creating a account
    Password = Get-ComplexRandomPassword -Length 16 -NonAlphaChars 5 # Only required when Azure Authentication is not enabled in Outsystems
}

# Troubleshooting
# $account = [PSCustomObject]@{
#     UserName = "TestHelloID@enyoi.onmicrosoft.com"
#     Name     = "Test HelloID"
#     IsActive = $false
#     Email    = "TestHelloID@enyoi.onmicrosoft.com"
#     Role     = "Administrator"  # This value is used to map title to a Outsystems Role, Which is required for creating a account
#     Password = Get-ComplexRandomPassword -Length 16 -NonAlphaChars 5 # Password is required, but not used, since Azure authentication is set up
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
#endregion functions

# Begin
try {
    # Verify if a user must be either [created], [updated and correlated] or just [correlated]
    $headers = New-AuthorizationHeaders -AccessToken $config.Token

    Write-Verbose 'Retrieve Account list from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($config.BaseUrl)/users?IncludeInactive=true"
        Headers = $headers
        Method  = 'GET'
    }
    $userList = Invoke-RestMethod @splatWebRequest -Verbose:$false

    Write-Verbose "Account lookup based on UserName [$($account.UserName)]"
    $responseUser = $userList | Where-Object { $_.Username -eq $account.UserName }

    if (-not($responseUser)) {
        $action = 'Create'
    } elseif ($updateAccount -eq $true) {
        $action = 'Update-Correlate'
    } else {
        $action = 'Correlate'
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action OutSystems account for: [$($p.DisplayName)], will be executed during enforcement"
            })
    }

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create' {
                Write-Verbose 'Creating OutSystems account'
                if ($account.Role) {
                    $roleObject = Invoke-CalculateDesiredRole -ScriptConfig $config -MappedRole $account.Role
                    Write-Verbose "Setting role to: $($roleObject.name) ($($roleObject.Key))"    
                    $account | Add-Member -NotePropertyMembers @{ RoleKey = $roleObject.Key }
                    $account.psobject.Properties.Remove("Role")
                }

                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users"
                    Headers = $headers
                    Method  = 'POST'
                    Body    = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                }
                $createdUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $accountReference = $createdUser.key

                # The API does not supports creating disabled accounts
                if ($account.IsActive -eq $false) {
                    Write-Verbose "Disabling OutSystems account"
                    $splatWebRequest = @{
                        Uri     = "$($config.BaseUrl)/users/$accountReference"
                        Headers = $headers
                        Method  = 'PUT'
                        Body    = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                    }
                    $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                }

                # # Only required when Azure Authentication is not enabled in Outsystems
                Write-Verbose 'Set Password OutSystems account'
                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users/$accountReference/setpassword"
                    Headers = $headers
                    Method  = 'POST'
                    Body    = (@{password = $account.Password } | ConvertTo-Json)
                }
                $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                break
            }

            'Update-Correlate' {
                Write-Verbose 'Updating and correlating OutSystems account'
                if ([string]::IsNullOrEmpty($responseUser.key)) {
                    throw "The user account [$($responseUser.Username) exists in Outsystem, but does not have a unique identifier [Key]"
                }
                if ($account.Role) {
                    $roleObject = Invoke-CalculateDesiredRole -ScriptConfig $config -MappedRole $account.Role
                    Write-Verbose "Setting role to: $($roleObject.name) ($($roleObject.Key))"
                    $account | Add-Member -NotePropertyMembers @{ RoleKey = $roleObject.Key }
                }
                $accountReference = $responseUser.key
                $splatWebRequest = @{
                    Uri     = "$($config.BaseUrl)/users/$($responseUser.key)"
                    Headers = $headers
                    Method  = 'PUT'
                    Body    = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                }
                $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                break
            }

            'Correlate' {
                Write-Verbose 'Correlating OutSystems account'
                if ([string]::IsNullOrEmpty($responseUser.key)) {
                    throw "The user account [$($responseUser.Username) exists in Outsystem, but does not have a unique identifier [Key]"
                }
                $accountReference = $responseUser.key
                break
            }
        }
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "$action account was successful. Username is: [$($account.UserName)]. AccountReference is: [$accountReference]"
                IsError = $false
            })
    }
} catch {
    $errorMessage = "Could not $action OutSystems account. Error: $($_.Exception.Message), $($_.ErrorDetails.Message)"
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = ( $account | Select-Object * -ExcludeProperty Password)
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}