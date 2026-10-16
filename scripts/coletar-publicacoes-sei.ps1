# Coleta publicações do SEI-UFSCar (Publicações Eletrônicas) relacionadas a pesquisa e inovação
# e grava data/publicacoes_sei.json. Busca pública, sem login.
# Estratégia: (1) todas as publicações de unidades de pesquisa; (2) buscas por palavras no resumo.
# Uso: powershell -File scripts/coletar-publicacoes-sei.ps1
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$saida = Join-Path $raiz 'data\publicacoes_sei.json'
$base = 'https://sei.ufscar.br/sei/publicacoes/'
$url  = $base + 'controlador_publicacoes.php?acao=publicacao_pesquisar&acao_origem=publicacao_pesquisar&id_orgao_publicacao=0'
$latin1 = [Text.Encoding]::GetEncoding('ISO-8859-1')

$unidades = [ordered]@{
  '110000022' = 'ProPq'; '110000786' = 'CoPq'; '110000750' = 'CIP'; '110000923' = 'CBF'
  '110000755' = 'IEAE';  '110000898' = 'CoIEAE'
}
$termos = 'pesquisa','pesquisador','pesquisadores','inovação','iniciação científica','bolsa','bolsas','propriedade intelectual',
          'propriedade industrial','ética','biossegurança','pós-doutorado','pós-doutor','fomento','CEUA','animais','patrimônio genético',
          'SisGen','EMBRAPII','tecnológica','transferência de tecnologia','pesquisa clínica','seres humanos','integridade'

function EncL1($s) { ($latin1.GetBytes($s) | ForEach-Object { if (($_ -ge 48 -and $_ -le 57) -or ($_ -ge 65 -and $_ -le 90) -or ($_ -ge 97 -and $_ -le 122)) { [char]$_ } else { '%{0:X2}' -f $_ } }) -join '' }

function Busca($campos, $inicio) {
  $b = [ordered]@{ hdnInfraTipoPagina = '1'; 'selOrgao[]' = '0'; txtInteiroTeor = ''; txtResumo = ''; selUnidadeResponsavel = 'null'
    selSerie = 'null'; txtNumero = ''; txtProtocoloPesquisa = ''; selVeiculoPublicacao = 'null'; txtDataDocumento = ''
    rdoDataPublicacao = 'I'; txtDataInicio = ''; txtDataFim = ''; hdnInicio = "$inicio"; sbmPesquisar = 'Pesquisar' }
  foreach ($k in $campos.Keys) { $b[$k] = $campos[$k] }
  $corpo = ($b.GetEnumerator() | ForEach-Object { (EncL1 $_.Key) + '=' + (EncL1 $_.Value) }) -join '&'
  for ($t = 1; $t -le 4; $t++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Post -Body $corpo -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 120
      $ms = New-Object IO.MemoryStream (,$r.RawContentStream.ToArray())
      return (New-Object IO.StreamReader($ms, $latin1)).ReadToEnd()
    } catch { Start-Sleep -Seconds (3 * $t) }
  }
  throw 'Falha repetida na busca'
}
function Limpa($s) { ([Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', ' ')) -replace '\s+', ' ').Trim() }

function Linhas($html) {
  foreach ($m in [regex]::Matches($html, '(?s)<tr id="trPublicacaoA\d+".*?</tr>')) {
    $td = [regex]::Matches($m.Value, '(?s)<td align="[^"]*" class="tdDados">(.*?)</td>')
    if ($td.Count -lt 8) { continue }
    $idDoc = [regex]::Match($td[0].Groups[1].Value, 'id_documento=(\d+)').Groups[1].Value
    $desc = Limpa $td[1].Groups[1].Value
    $mm = [regex]::Match($desc, '^(.*?)(?::\s*(.*?))?\s+(\d+[\w./-]*)$')
    [pscustomobject]@{
      protocolo = Limpa $td[0].Groups[1].Value
      idDocumento = $idDoc
      descricao = $desc
      veiculo = Limpa $td[2].Groups[1].Value
      data = Limpa $td[3].Groups[1].Value
      unidade = [Net.WebUtility]::HtmlDecode([regex]::Match($td[4].Groups[1].Value, 'title="([^"]*)"').Groups[1].Value)
      sigla = Limpa $td[4].Groups[1].Value
      resumo = Limpa $td[6].Groups[1].Value
      link = $base + "controlador_publicacoes.php?acao=publicacao_visualizar&id_documento=$idDoc&id_orgao_publicacao=0"
    }
  }
}

$mapa = @{}
function Varre($campos, $rotulo) {
  $ini = 0; $total = $null
  do {
    $h = Busca $campos $ini
    $barra = [regex]::Match($h, 'pesquisaBarraD">([^<]*)').Groups[1].Value
    if ($null -eq $total) {
      $n = [regex]::Match($barra, 'de ([\d.]+)$').Groups[1].Value
      if (-not $n) { $n = [regex]::Match($barra, '^(\d+) resultado').Groups[1].Value }
      $total = if ($n) { [int]($n -replace '\.', '') } else { 0 }
      Write-Host ("{0}: {1}" -f $rotulo, $total)
    }
    $ls = @(Linhas $h)
    foreach ($l in $ls) {
      if (-not $mapa.ContainsKey($l.protocolo)) { $l | Add-Member origem @() ; $mapa[$l.protocolo] = $l }
      if ($mapa[$l.protocolo].origem -notcontains $rotulo) { $mapa[$l.protocolo].origem += $rotulo }
    }
    $ini += 20
    if ($ls.Count -eq 0) { break }
    Start-Sleep -Milliseconds 400
  } while ($ini -lt $total)
}

foreach ($id in $unidades.Keys) { Varre @{ selUnidadeResponsavel = $id } ("Unidade " + $unidades[$id]) }
foreach ($t in $termos) { Varre @{ txtResumo = $t } ("Resumo: $t") }

$res = [pscustomobject]@{
  fonte = $url; coletadoEm = (Get-Date).ToString('yyyy-MM-dd')
  criterios = @($unidades.Values | ForEach-Object { "Unidade $_" }) + @($termos | ForEach-Object { "Resumo: $_" })
  publicacoes = @($mapa.Values)
}
$res | ConvertTo-Json -Depth 5 | Set-Content -Path $saida -Encoding utf8
Write-Host "Gravado: $saida ($($mapa.Count) publicações)"
