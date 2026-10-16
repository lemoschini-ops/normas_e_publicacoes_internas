# Agenda a atualização diária no Windows (Agendador de Tarefas), todo dia às 03:00.
# Uso (uma vez): powershell -File scripts/agendar-windows.ps1   |  remover: -Remover
param([string]$Hora = '03:00', [switch]$Remover)
$nome = 'Atualizar normas UFSCar'
if ($Remover) { Unregister-ScheduledTask -TaskName $nome -Confirm:$false; Write-Host 'Tarefa removida.'; return }
$script = Join-Path $PSScriptRoot 'atualizar.ps1'
$acao = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WorkingDirectory (Split-Path -Parent $PSScriptRoot)
$gatilho = New-ScheduledTaskTrigger -Daily -At $Hora
$cfg = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)
Register-ScheduledTask -TaskName $nome -Action $acao -Trigger $gatilho -Settings $cfg -Force | Out-Null
Write-Host "Tarefa '$nome' agendada para $Hora diariamente (se o PC estiver desligado, roda quando ligar)."
