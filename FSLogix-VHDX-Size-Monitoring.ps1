<#
.SYNOPSIS
    FSLogix VHDX Size Monitoring

.DESCRIPTION
    PowerShell script to monitor VHD and VHDX file size.

.INPUTS
    No parameters. Variables are supposed to be set by the rmm solution this script is used in.

.OUTPUTS
    Exit Code 0 = Successful - No files exceed any threshold.
    Exit Code 1 = Alert - At least one file exceeds the alert threshold or something else went wrong and the check wasn't executed successfully.
    Exit Code 2 = Warning - No file exceeds the alert threshold. At least one file exceeds the warning threshold.

.LINK
    https://github.com/MichaelSchoenburg/FSLogix-VHDX-Size-Monitoring

.NOTES
    Author: Michael Schönburg
    Version: v1.0
    
    This projects code loosely follows the PowerShell Practice and Style guide, as well as Microsofts PowerShell scripting performance considerations.
    Style guide: https://poshcode.gitbook.io/powershell-practice-and-style/
    Performance Considerations: https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations?view=powershell-7.1
#>

#region INITIALIZATION
<# 
    Libraries, Modules, ...
#>

#endregion INITIALIZATION
#region DECLARATIONS
<#
    Declare local variables and global variables
#>

<# 

# The following variables should be set through your rmm solution. 
# Here some examples of possible declarations with explanations for each variable.
# Tip: PowerShell variables are not case sensitive.

# Define either $FSLogixDir or Share, never both!
$FSLogixDir = "Z:\FSLogix"
$Share = FSLogix$

$ThresholdWaring = 27
$ThresholdAlert = 29

#>

# Set defaults, if not defined already
if ($ThresholdWaring -eq $null) {
    $ThresholdWaring = 27
}

if ($ThresholdAlert -eq $null) {
    $ThresholdAlert = 29
}

# Declare counters
$Alerts = 0
$Warnings = 0

#endregion DECLARATIONS
#region FUNCTIONS
<# 
    Declare Functions
#>

function Write-ConsoleLog {
    <#
    .SYNOPSIS
    Logs an event to the console.
    
    .DESCRIPTION
    Writes text to the console with the current date (US format) in front of it.
    
    .PARAMETER Text
    Event/text to be outputted to the console.
    
    .EXAMPLE
    Write-ConsoleLog -Text 'Subscript XYZ called.'
    
    Long form
    .EXAMPLE
    Log 'Subscript XYZ called.
    
    Short form
    #>
    [alias('Log')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
        Position = 0)]
        [string]
        $Text
    )

    # Save current VerbosePreference
    $VerbosePreferenceBefore = $VerbosePreference

    # Enable verbose output
    $VerbosePreference = 'Continue'

    # Write verbose output
    Write-Verbose "$( Get-Date -Format 'MM/dd/yyyy HH:mm:ss' ) - $( $Text )"

    # Restore current VerbosePreference
    $VerbosePreference = $VerbosePreferenceBefore
}

#endregion FUNCTIONS
#region EXECUTION
<# 
    Script entry point
#>

if (($FSLogixDir -eq $null) -and ($Share -eq $null)) {
    Log "ERROR! Sie haben keinen Ort angegeben. Befüllen Sie entweder $FSLogixDir oder $Share."
    Exit 1
} elseif (($FSLogixDir) -and ($Share)) {
    Log "ERROR! Sie haben $FSLogixDir UND $Share angegeben. Welchen soll ich nun benutzen? Bitte nur eins von beidem angeben."
    Exit 1
} elseif ($FSLogixDir) {
    Log "Sie haben folgenden Pfad angegeben: $($FSLogixDir)"
    $Files = Get-ChildItem -Path $FSLogixDir -Include "*.vhdx", "*vhd" -Recurse
    Log "Dort habe ich $($Files.Count) VHDX- oder VHD-Dateien finden können."
} elseif ($Share) {
    # Use "nltest /dsgetdc:" to resolve the domain controller
    $results = ((nltest /dsgetdc:) -replace ":", "=" -replace '\\', '\\' | Where-Object{$_ -match "="}) -join "`r`n" | ConvertFrom-StringData
    new-object -TypeName PSCustomObject -Property $results
    $Share = $Share.TrimStart('\')
    $Path = $results.Domänencontroller + '\' + $Share
    Log "Sie haben '$($Share)' als $Share angegeben. Ich habe '$($env:LOGONSERVER)', als Domain Controller identifiziert. Daraus ergibt sich folgender Netzwerkpfad: $($Path)"
    $Files = Get-ChildItem -Path $Path Include "*.vhdx", "*vhd" -Recurse
    Log "Dort habe ich $($Files.Count) VHDX- oder VHD-Dateien finden können."
}

foreach ($f in $Files) {
    $size = (Get-Item $f.FullName).Length
    $sizeInGB = [math]::Round($size / 1GB,2)
    if ($sizeInGB -gt $ThresholdAlert) {
        "ALARM: Datei '$($f.Name)' ist $($sizeInGB) GB groß."
        $Alerts++
    } elseif ($sizeInGB -gt $ThresholdWaring) {
        "VORSICHT: Datei '$($f.Name)' ist $($sizeInGB) GB groß."
        $Warning++
    } else {
        "INFO: Datei '$($f.Name)' ist $($sizeInGB) GB groß."
    }
}

if ($Alerts -gt 0) {
    Exit 1
} elseif ($Warnings -gt 0) {
    Exit 2
} else {
    Exit 0
}

#endregion EXECUTION
