#####################################################
# HelloID-Conn-Prov-Target-OutSystems-Enable
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
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

# Troubleshooting
# $aRef = "12345678-bf9b-4e2f-9cbc-abcdefghij"
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
#endregion

try {
    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "Enable OutSystems account for: [$($p.DisplayName)] will be executed during enforcement"
            })
    }
    $headers = New-AuthorizationHeaders -AccessToken $config.Token

    Write-Verbose 'Retrieve existing account from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($config.BaseUrl)/users/$aref"
        Headers = $headers
        Method  = 'GET'
    }
    $CurrentUser = Invoke-RestMethod @splatWebRequest -Verbose:$false
    $CurrentUser.IsActive = $true

    if (-not($dryRun -eq $true)) {
        Write-Verbose "Enabling OutSystems account with accountReference: [$aRef]"
        $splatWebRequest['Method'] = 'PUT'
        $splatWebRequest['Body'] = ($CurrentUser | ConvertTo-Json)
        $null = Invoke-RestMethod @splatWebRequest -Verbose:$false
        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Action  = "EnableAccount"
                Message = "Enable account was successful for account with accountReference: [$aRef]"
                IsError = $false
            })
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        # $errorObj = Resolve-HTTPError -ErrorObject $ex
        # $errorMessage = "Could not enable OutSystems account with accountReference: [$($aRef)]. Error: $($errorObj.ErrorMessage)"
        
        $errorObjectConverted = $_ | ConvertFrom-Json
        $errorMessage = "Could not enable OutSystems account with accountReference: [$($aRef)]. Error: $($errorObjectConverted.Errors)"
    } else {
        $errorMessage = "Could not enable OutSystems account with accountReference: [$($aRef)]. Error: $($ex.Exception.Message)"
    }

    $verboseErrorMessage = "Could not enable OutSystems account with accountReference: [$($aRef)]. Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    Write-Verbose $verboseErrorMessage

    $auditLogs.Add([PSCustomObject]@{
            Action  = "EnableAccount"
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}