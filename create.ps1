#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Set to true if accounts in the target system must be updated
$updateAccount = $true

#region helper functions
function Get-ComplexRandomPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Length,
        [Parameter(Mandatory = $true)]
        $NonAlphaChars
    )
    
    $password = [System.Web.Security.Membership]::GeneratePassword($Length, $NonAlphaChars);
    
    return $password;
}
#endregion helper functions

# Account mapping
$account = [PSCustomObject]@{
    UserName = $p.Accounts.MicrosoftActiveDirectory.UserPrincipalName
    Name     = $p.Accounts.MicrosoftActiveDirectory.DisplayName # $p.DisplayName
    IsActive = $false
    Email    = $p.Accounts.MicrosoftActiveDirectory.mail
    # Password = Get-ComplexRandomPassword -Length 16 -NonAlphaChars 5 # Only required when Azure Authentication is not enabled in Outsystems
}

# Troubleshooting
# $account = [PSCustomObject]@{
#     UserName = "TestHelloID@enyoi.onmicrosoft.com"
#     Name     = "Test HelloID"
#     IsActive = $false
#     Email    = "TestHelloID@enyoi.onmicrosoft.com"
#     Password = Get-ComplexRandomPassword -Length 16 -NonAlphaChars 5 # Password is required, but not used, since Azure authentication is set up
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
#endregion functions

# Begin
try {
    # Verify if a user must be either [created], [updated and correlated] or just [correlated]
    $headers = New-AuthorizationHeaders -AccessToken $c.Token

    Write-Verbose 'Retrieve Account list from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/users?IncludeInactive=true"
        Headers = $headers
        Method  = 'GET'
    }
    $userList = Invoke-RestMethod @splatWebRequest -Verbose:$false

    Write-Verbose "Account lookup based on UserName [$($account.UserName)]"
    $CurrentUser = $userList | Where-Object { $_.Username -eq $account.UserName }

    if (-not($CurrentUser)) {
        $action = 'Create'
    }
    elseif ($updateAccount -eq $true) {
        $action = 'Update-Correlate'


        # Verify if the account must be updated
        $splatCompareProperties = @{
            ReferenceObject  = @($CurrentUser.PSObject.Properties)
            DifferenceObject = @($account.PSObject.Properties)
        }
        $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where( { $_.SideIndicator -eq '=>' })
        if ($propertiesChanged) {
            Write-Verbose "Account property(s) required to update: [$($propertiesChanged.name -join ",")]"
            $updateAction = 'Update'
        } else {
            $updateAction = 'NoChanges'
        }
    }
    else {
        $action = 'Correlate'
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action OutSystems account for: [$($p.DisplayName)], will be executed during enforcement"
            })
    }

    # Get all roles and group by key
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/roles"
        Headers = $headers
        Method  = 'GET'
    }
    $roleList = Invoke-RestMethod @splatWebRequest -Verbose:$false
    $roleListGrouped = $roleList | Group-Object -Property Key -AsHashTable -AsString

    # Process
    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Create' {
                Write-Verbose 'Creating OutSystems account'

                # Set default role
                if($null -eq $c.defaultRole){
                    throw "No default role is configured. Please configure this, as a role is required in OutSystems"
                }
                $roleObject = $roleList.Where( { $_.name -eq $c.defaultRole })

                if ($null -eq $roleObject) {
                    throw "Unable to find a Role with name: $($c.defaultRole)"
                }
                $auditLogs.Add([PSCustomObject]@{
                    Message = "Role for Outsystems Account will be set to: $($roleFound.name) ($($roleFound.Key))"
                })

                Write-Verbose "Setting role to: $($roleObject.name) ($($roleObject.Key))"    
                $account | Add-Member -NotePropertyMembers @{ RoleKey = $roleObject.Key }
                
                $body = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                $splatWebRequest = @{
                    Uri     = "$($c.BaseUrl)/users"
                    Headers = $headers
                    Method  = 'POST'
                    Body    = ([System.Text.Encoding]::UTF8.GetBytes($body)) 
                }
                $createdUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
                $aRef = [PSCustomObject]@{
                    id       = $createdUser.key
                    username = $createdUser.username
                }
                $roleName = $roleListGrouped["$($createdUser.RoleKey)"].Name

                # The API does not supports creating disabled accounts
                if ($account.IsActive -eq $false) {
                    Write-Verbose "Disabling OutSystems account"
                    $body = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                    $splatWebRequest = @{
                        Uri     = "$($c.BaseUrl)/users/$($createdUser.key)"
                        Headers = $headers
                        Method  = 'PUT'
                        Body    = ([System.Text.Encoding]::UTF8.GetBytes($body)) 
                    }
                    $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                }

                # # Only required when Azure Authentication is not enabled in Outsystems
                # Write-Verbose 'Set Password OutSystems account'
                # $body = ($account | Select-Object * -ExcludeProperty password | ConvertTo-Json)
                # $splatWebRequest = @{
                #     Uri     = "$($c.BaseUrl)/users/$($createdUser.key)/setpassword"
                #     Headers = $headers
                #     Method  = 'POST'
                #     Body    = ([System.Text.Encoding]::UTF8.GetBytes($body)) 
                # }
                # $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
                break
            }

            'Update-Correlate' {
                Write-Verbose 'Updating and correlating OutSystems account'
                if ([string]::IsNullOrEmpty($CurrentUser.key)) {
                    throw "The user account [$($CurrentUser.Username) exists in Outsystem, but does not have a unique identifier [Key]"
                }

                switch ($updateAction) {
                    'Update' {
                        foreach ($property in ($propertiesChanged.where({$_.name -ne 'Role' }))) {
                            $CurrentUser.$($property.name) = $property.value
                        }

                        $body = ($CurrentUser | ConvertTo-Json)
                        Write-Verbose "Updating OutSystems account $($aref.username) ($($aRef.id))"
                        Write-Verbose "Body: $body"
                        $splatWebRequest = @{
                            Uri     = "$($c.BaseUrl)/users/$($CurrentUser.key)"
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
                                Action = "UpdateAccount"
                                Message = "Update account was successful"
                                IsError = $false
                            })
                        break
                    }
                    'NoChanges' {
                        $aRef = [PSCustomObject]@{
                            id       = $CurrentUser.key
                            username = $CurrentUser.username
                        }
                        $roleName = $roleListGrouped["$($CurrentUser.RoleKey)"].Name

                        Write-Verbose "No changes to OutSystems account $($CurrentUser.username) ($($CurrentUser.key))"
                        $auditLogs.Add([PSCustomObject]@{
                                Action = "UpdateAccount"
                                Message = "Update was successful (No Changes needed)"
                                IsError = $false
                            })
                        break
                    }
                }
                break
            }

            'Correlate' {
                Write-Verbose 'Correlating OutSystems account'
                if ([string]::IsNullOrEmpty($CurrentUser.key)) {
                    throw "The user account [$($CurrentUser.Username) exists in Outsystem, but does not have a unique identifier [Key]"
                }
                $aRef = [PSCustomObject]@{
                    id       = $CurrentUser.key
                    username = $CurrentUser.username
                }
                $roleName = $roleListGrouped["$($CurrentUser.RoleKey)"].Name
                break
            }
        }
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount"
                Message = "$action account was successful. Username is: [$($account.UserName)]. AccountReference is: [$aRef]"
                IsError = $false
            })
    }
}
catch {
    $errorMessage = "Could not $action OutSystems account. Error: $($_.Exception.Message), $($_.ErrorDetails.Message)"
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $aRef
        Auditlogs        = $auditLogs
        Account          = ( $account | Select-Object * -ExcludeProperty Password)
 
        # Optionally return data for use in other systems
        ExportData       = [PSCustomObject]@{
            id          = $aRef.id;
            username    = $aRef.username;
            role        = $roleName;
        }; 
    }

    Write-Output $result | ConvertTo-Json -Depth 10
}