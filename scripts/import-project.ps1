param(
  [Parameter(Mandatory)][string]$ProjectId,
  [Parameter(Mandatory)][string]$Zip,
  [Parameter(Mandatory)][string]$VarsFile,
  [string]$Context = 'pilgrims'
)
# Imports a packed project into an EMPTY project that you created. Asks nothing: only run it after the user approved the import.
# A first import into a new project always fails with "required bindings are missing".
# Then the export variables are set and the import runs again. $VarsFile must be UTF-8 without BOM.
$ErrorActionPreference = 'Stop'

function Wait-Action([string]$Id) {
  for ($i = 0; $i -lt 120; $i++) {
    $s = qlik raw get "v1/di-projects/actions/$Id" --context $Context | ConvertFrom-Json
    if ($s.state -in 'COMPLETED', 'FAILED', 'CANCELED') { return $s }
    Start-Sleep 3
  }
  throw "Action $Id did not finish"
}
function Import-Once {
  $r = qlik di-project import-async $ProjectId --context $Context --zip $Zip --json | ConvertFrom-Json
  Wait-Action $r.actionId
}

$s = Import-Once
if ($s.state -ne 'COMPLETED') {
  "First import: $($s.state) - $($s.error.message)"
  qlik di-project export-variables set $ProjectId --context $Context -f $VarsFile | Out-Null
  $s = Import-Once
}
if ($s.state -ne 'COMPLETED') { throw "Import failed: $($s.error.message)" }
'Import completed.'
qlik di-project di-task ls --di-projectId $ProjectId --context $Context --json | ConvertFrom-Json | ForEach-Object { $_.id }
