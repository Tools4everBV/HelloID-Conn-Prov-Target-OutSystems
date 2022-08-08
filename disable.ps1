#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Disable
#
# Version: 1.0.0
#####################################################
# Initialize default values
$c = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# Set debug logging
switch ($($c.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

# Troubleshooting
# $aRef = @{
#     Username = "TestHelloID@enyoi.onmicrosoft.com"
#     id = "12345678-bf9b-4e2f-9cbc-abcdefghij"
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

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Disable OutSystems account for: [$($p.DisplayName)] will be executed during enforcement"
            })
    }

    $headers = New-AuthorizationHeaders -AccessToken $c.Token
    Write-Verbose 'Retrieve existing account from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/users/$($aRef.id)"
        Headers = $headers
        Method  = 'GET'
    }
    $CurrentUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
    $CurrentUser.IsActive = $false

    if (-not($dryRun -eq $true)) {
        Write-Verbose "Disabling OutSystems account $($aRef.username) ($($aRef.id))"
        $splatWebRequest['Method'] = 'PUT'
        $body = ($CurrentUser | ConvertTo-Json)
        $splatWebRequest['Body'] = ([System.Text.Encoding]::UTF8.GetBytes($body)) 
        $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "DisableAccount"
                Message = "Disable account was successful for account $($aRef.username) ($($aRef.id))"
                IsError = $false
            })
    }
}
catch {
    $ex = $PSItem

    # Define (general) action message
    $actionMessage = "Could not disable OutSystems account $($aref.username) ($($aRef.id))"

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
            Action  = "DisableAccount"
            Message = "$($actionMessage). Error: $auditErrorMessage"
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}