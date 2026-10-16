# Coleta os atos normativos vigentes da UFSCar (Consulta Geral + cada eixo temático)
# e grava data/normas.json. Uso: powershell -File scripts/coletar-normas.ps1
$ErrorActionPreference = 'Stop'
$base = 'https://www.ufscar.br/atos-normativos-da-ufscar'
$raiz = Split-Path -Parent $PSScriptRoot
$saida = Join-Path $raiz 'data\normas.json'

function Get-Html($url) {
  (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 120).Content
}
function Limpa($s) {
  [System.Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', ' ')) -replace '\s+', ' ' | ForEach-Object { $_.Trim() }
}
function Get-Linhas($html) {
  $out = @()
  foreach ($tr in [regex]::Matches($html, '(?s)<tr>\s*(<td>.*?)</tr>')) {
    $cel = [regex]::Matches($tr.Groups[1].Value, '(?s)<td>(.*?)</td>')
    if ($cel.Count -lt 6) { continue }
    $href = [regex]::Match($cel[5].Groups[1].Value, 'href="([^"]+)"').Groups[1].Value
    $out += [pscustomobject]@{
      unidade = Limpa $cel[0].Groups[1].Value
      tipo    = Limpa $cel[1].Groups[1].Value
      numero  = Limpa $cel[2].Groups[1].Value
      ano     = Limpa $cel[3].Groups[1].Value
      ementa  = Limpa $cel[4].Groups[1].Value
      link    = [System.Net.WebUtility]::HtmlDecode($href)
    }
  }
  $out
}

# Eixos temáticos listados na página principal
$pagina = Get-Html $base
$bloco = [regex]::Match($pagina, '(?s)id="consulta-por-eixo-tematico".*?</div>').Value
$eixos = [regex]::Matches($bloco, '<a [^>]*href="(https://www\.ufscar\.br/atos-normativos-da-ufscar/[^"]+)"[^>]*>(.*?)</a>') |
  ForEach-Object { [pscustomobject]@{ url = $_.Groups[1].Value; nome = Limpa $_.Groups[2].Value } }
Write-Host "Eixos: $($eixos.Count)"

$geral = Get-Linhas (Get-Html "$base/atos-normativos-vigentes-da-ufscar-consulta-geral")
Write-Host "Consulta Geral: $($geral.Count) normas"

# chave = link SEI + tipo/número/ano; unidades distintas do mesmo ato são unidas com " / "
function Chave($n) { "$($n.link)|$($n.tipo)|$($n.numero)|$($n.ano)" }
$mapa = @{}
foreach ($n in $geral) {
  $k = Chave $n
  if ($mapa.ContainsKey($k)) {
    if ($mapa[$k].unidade -notmatch [regex]::Escape($n.unidade)) { $mapa[$k].unidade += " / $($n.unidade)" }
    continue
  }
  $n | Add-Member -NotePropertyName eixos -NotePropertyValue @() -Force
  $mapa[$k] = $n
}
foreach ($e in $eixos) {
  $linhas = Get-Linhas (Get-Html $e.url)
  Write-Host ("  {0}: {1}" -f $e.nome, $linhas.Count)
  foreach ($l in $linhas) {
    $k = Chave $l
    if (-not $mapa.ContainsKey($k)) { $l | Add-Member -NotePropertyName eixos -NotePropertyValue @() -Force; $mapa[$k] = $l }
    if ($mapa[$k].eixos -notcontains $e.nome) { $mapa[$k].eixos += $e.nome }
  }
}

$resultado = [pscustomobject]@{
  fonte   = "$base/atos-normativos-vigentes-da-ufscar-consulta-geral"
  coletadoEm = (Get-Date).ToString('yyyy-MM-dd')
  eixos   = @($eixos | ForEach-Object { $_.nome })
  normas  = @($mapa.Values)
}
$resultado | ConvertTo-Json -Depth 5 | Set-Content -Path $saida -Encoding utf8
Write-Host "Gravado: $saida ($($mapa.Count) normas)"


