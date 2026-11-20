param(
  [Parameter(Mandatory)][string]$Folder,
  [string]$Zip = (Join-Path $env:TEMP ((Split-Path $Folder -Leaf) + '.zip')),
  [string]$Context = 'pilgrims'
)
# Packs a QTC project folder into an import zip and validates it. Needs PowerShell 7+.
$ErrorActionPreference = 'Stop'
$Folder = (Resolve-Path $Folder).Path
$utf8 = New-Object Text.UTF8Encoding($false)

$bad = @()
foreach ($f in Get-ChildItem -Recurse -File $Folder | Where-Object { $_.Extension -in '.json', '.yaml', '.yml' }) {
  $t = [IO.File]::ReadAllText($f.FullName)
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) {
    [IO.File]::WriteAllText($f.FullName, $t.TrimStart([char]0xFEFF), $utf8)
    $bad += $f.Name
  }
}
if ($bad) { "Removed BOM from: $($bad -join ', ')" }

if (Test-Path $Zip) { Remove-Item $Zip -Force }
Add-Type -A System.IO.Compression
$fs = [IO.File]::Open($Zip, 'Create')
$za = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
Get-ChildItem -Recurse -File $Folder | ForEach-Object {
  $rel = $_.FullName.Substring($Folder.Length + 1).Replace('\', '/')
  $e = $za.CreateEntry($rel, [IO.Compression.CompressionLevel]::Optimal)
  $st = $e.Open(); $b = [IO.File]::ReadAllBytes($_.FullName); $st.Write($b, 0, $b.Length); $st.Close()
}
$za.Dispose(); $fs.Close()
"Packed $Zip"

qlik di-project util validate-project-definitions --zip $Zip --context $Context
if ($LASTEXITCODE -ne 0) { throw 'validate-project-definitions failed' }
