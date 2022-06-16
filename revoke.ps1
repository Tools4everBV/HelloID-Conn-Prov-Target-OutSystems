#region Initialize default properties
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json;
$m = $manager | ConvertFrom-Json;
$aRef = $accountReference | ConvertFrom-Json;
$mRef = $managerAccountReference | ConvertFrom-Json;

# The permissionReference object contains the Identification object provided in the retrieve permissions call
$pRef = $permissionReference | ConvertFrom-Json;

$success = $True
$auditLogs = [Collections.Generic.List[PSCustomObject]]::new()

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Troubleshooting
# $aRef = @{
#     Username = "TestHelloID@enyoi.onmicrosoft.com"
#     id = "12345678-bf9b-4e2f-9cbc-abcdefghij"
# }
# $dryRun = $false

#region functions
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

try {
    if ($null -eq $aRef.id) {
        throw "No Account Reference found in HelloID"
    }

    $headers = New-AuthorizationHeaders -AccessToken $c.Token

    # Set RoleKey for previous account object with RoleKey from current user object
    Write-Verbose "Retrieve existing account from OutSystems with id: $($aRef.id)"
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/users/$($aRef.id)"
        Headers = $headers
        Method  = 'GET'
    }
    $CurrentUser = Invoke-RestMethod @splatWebRequest -Verbose:$false

    if ($null -eq $CurrentUser) {
        throw "No existing account found in OutSystems with id: $($aRef.id)"
    }

    # Get all roles and group by key
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/roles"
        Headers = $headers
        Method  = 'GET'
    }
    $roleList = Invoke-RestMethod @splatWebRequest -Verbose:$false
    $roleListGrouped = $roleList | Group-Object -Property Key -AsHashTable -AsString

    # Overwrite role with default role
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

    $CurrentUser.RoleKey = $roleObject.Key 

    Write-Verbose "Reverting to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id))"

    $body = ($CurrentUser | ConvertTo-Json)
    Write-Verbose "Updating OutSystems account $($aref.username) ($($aRef.id))"
    Write-Verbose "Body: $body"
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/users/$($aRef.id)"
        Headers = $headers
        Method  = 'PUT'
        Body    = ([System.Text.Encoding]::UTF8.GetBytes($body))
    }
    if ($dryRun -eq $false) {
        $updatedUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
        $roleName = $roleListGrouped["$($updatedUser.RoleKey)"].Name
        
        Write-Verbose "Successfully reverted to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id))"
    } else {
        # Dry run logging
        Write-Verbose ($splatWebRequest.Uri)
        Write-Verbose ($splatWebRequest.Body)
    }

    $success = $true
    $auditLogs.Add([PSCustomObject]@{
            Action  = "RevokePermission"
            Message = "Successfully reverted to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id))"
            IsError = $false
        })

}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        # $errorObj = Resolve-HTTPError -ErrorObject $ex
        # $errorMessage = "Could not revoke $($pRef.Name) ($($pRef.id)) to $($aRef.username) ($($aRef.id)). Error: $($errorObj.ErrorMessage)"
        
        $errorObjectConverted = $_ | ConvertFrom-Json
        $errorMessage = "Could not revert to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id)). Error: $($errorObjectConverted.Errors)"
    } else {
        $errorMessage = "Could not revert to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id)). Error: $($ex.Exception.Message)"
    }

    $verboseErrorMessage = "Could not revert to default role $($roleObject.name) ($($roleObject.Key)) for $($aRef.username) ($($aRef.id)). Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    Write-Verbose $verboseErrorMessage
  
    $auditLogs.Add([PSCustomObject]@{
            Action = "RevokePermission"
            Message = $errorMessage
            IsError = $true
        })
}

#build up result
$result = [PSCustomObject]@{ 
    Success   = $success
    AuditLogs = $auditLogs
    Account   = $CurrentUser
    
    # Optionally return data for use in other systems
    ExportData       = [PSCustomObject]@{
        id          = $aRef.id;
        username    = $aRef.username;
        role        = $roleName;
    }; 
};

Write-Output $result | ConvertTo-Json -Depth 10;