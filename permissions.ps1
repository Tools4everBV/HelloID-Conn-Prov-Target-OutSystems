$c = $configuration | ConvertFrom-Json

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
    # Verify if a user must be either [created], [updated and correlated] or just [correlated]
    $headers = New-AuthorizationHeaders -AccessToken $c.Token

    Write-Verbose 'Retrieve Role list from OutSystems'
    $splatWebRequest = @{
        Uri     = "$($c.BaseUrl)/roles"
        Headers = $headers
        Method  = 'GET'
    }
    $roleList = Invoke-RestMethod @splatWebRequest -Verbose:$false

    Write-Information "Successfully retrieved Role list from OutSystems. Result count: $($roleList.Key.Count)"
}
catch {
    $ex = $PSItem

    # Define (general) action message
    $actionMessage = "Could not retrieve Role list from OutSystems"

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

    # throw terminating error
    throw "$($actionMessage). Error: $auditErrorMessage"
}

foreach ($role in $roleList) {
    $returnObject = @{
        DisplayName    = "Role - $($role.name)";
        Identification = @{
            id   = $role.Key
            Name = $role.name
            Type = "Role"
        }
    };

    Write-Output $returnObject | ConvertTo-Json -Depth 10
}