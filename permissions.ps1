$c = $configuration | ConvertFrom-Json

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($c.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}
$InformationPreference = "Continue"
$WarningPreference = "Continue"

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

    $verboseErrorMessage = "Could not retrieve Role list from OutSystems. Error at Line '$($_.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    Write-Verbose $verboseErrorMessage

    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        # $errorObj = Resolve-HTTPError -ErrorObject $ex
        # $errorMessage = "Could not retrieve Role list from OutSystems. Error: $($errorObj.ErrorMessage)"
        
        $errorObjectConverted = $_ | ConvertFrom-Json
        $errorMessage = "Could not retrieve Role list from OutSystems. Error: $($errorObjectConverted.Errors)"
    }
    else {
        $errorMessage = "Could not retrieve Role list from OutSystems. Error: $($ex.Exception.Message)"
    }

    throw $errorMessage
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