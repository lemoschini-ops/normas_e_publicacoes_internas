# Atualização completa: recoleta normas e publicações do SEI, valida e regenera normas.html.
# Mantém os dados antigos se a coleta falhar ou vier muito menor (site fora do ar, bloqueio etc.).
# Uso: powershell -File scripts/atualizar.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$dados = Join-Path $raiz 'data'
$log = Join-Path $dados 'atualizacao.json'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('norm_bkp_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

# nome do arquivo, script coletor, campo da lista, queda máxima aceita (fração)
$fontes = @(
  @{ arq = 'normas.json';          script = 'coletar-normas.ps1';          campo = 'normas';      min = 0.8 }
  @{ arq = 'publicacoes_sei.json'; script = 'coletar-publicacoes-sei.ps1'; campo = 'publicacoes'; min = 0.8 }
)
function Conta($arq, $campo) {
  if (-not (Test-Path $arq)) { return 0 }
  @((Get-Content $arq -Raw -Encoding utf8 | ConvertFrom-Json).$campo).Count
}
$resumo = [ordered]@{ executadoEm = (Get-Date).ToString('s'); fontes = @() }
$falhou = $false
foreach ($f in $fontes) {
  $dest = Join-Path $dados $f.arq
  $antes = Conta $dest $f.campo
  if (Test-Path $dest) { Copy-Item $dest (Join-Path $tmp $f.arq) }
  $status = 'ok'; $erro = ''
  try {
    & (Join-Path $PSScriptRoot $f.script) | Out-Host
    $depois = Conta $dest $f.campo
    if ($depois -lt 1 -or ($antes -gt 0 -and $depois -lt $antes * $f.min)) { throw "contagem suspeita: $antes -> $depois" }
  } catch {
    $status = 'revertido'; $erro = $_.Exception.Message; $falhou = $true
    if (Test-Path (Join-Path $tmp $f.arq)) { Copy-Item (Join-Path $tmp $f.arq) $dest -Force }
    $depois = $antes
    Write-Warning "$($f.arq): $erro (dados anteriores mantidos)"
  }
  $resumo.fontes += [ordered]@{ arquivo = $f.arq; antes = $antes; depois = $depois; status = $status; erro = $erro }
}
Remove-Item $tmp -Recurse -Force
& (Join-Path $PSScriptRoot 'gerar-normas.ps1') | Out-Host
$resumo | ConvertTo-Json -Depth 4 | Set-Content $log -Encoding utf8
if ($falhou) { Write-Warning 'Atualização concluída com avisos (veja data/atualizacao.json).' }
