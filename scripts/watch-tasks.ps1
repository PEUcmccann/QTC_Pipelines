param(
  [Parameter(Mandatory)][string]$ProjectId,
  [string]$Context = 'pilgrims',
  [int]$IntervalSeconds = 30,
  [int]$MaxMinutes = 30
)
# Prints one line per task with its last run state and full-load counts. Stops when no task is active.
$deadline = (Get-Date).AddMinutes($MaxMinutes)
$ids = qlik di-project di-task ls --di-projectId $ProjectId --context $Context --json | ConvertFrom-Json | ForEach-Object { $_.id } | Sort-Object
do {
  $active = 0; $parts = @()
  foreach ($t in $ids) {
    $s = qlik di-project di-task runtime state --di-projectId $ProjectId --di-taskId $t --context $Context --json | ConvertFrom-Json
    $st = $s.lastRun.state; if (-not $st) { $st = $s.runReadiness.state }
    if ($s.runReadiness.state -eq 'ALREADY_RUNNING' -or $st -in 'RUNNING', 'STARTING', 'QUEUED', 'EXECUTING') { $active++ }
    $fl = $s.lastRun.fullLoad
    $short = $t -replace '-.*$', ''
    $parts += "$short=$st(load=$($fl.loadingCount) done=$($fl.completedCount) err=$($fl.errorCount))"
    if ($st -eq 'FAILED') { $parts += "[$($s.lastRun.message)]" }
  }
  '{0:HH:mm:ss} {1}' -f (Get-Date), ($parts -join ' ')
  if ($active -eq 0) { break }
  Start-Sleep $IntervalSeconds
} while ((Get-Date) -lt $deadline)
