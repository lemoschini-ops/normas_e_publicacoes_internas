# Gera normas.html embutindo data/normas.json e data/publicacoes_sei.json em src/template-normas.html
$raiz = Split-Path -Parent $PSScriptRoot
function Json($nome) { (Get-Content (Join-Path $raiz "data\$nome") -Raw -Encoding utf8).Replace('</', '<\/') }
$tpl = Get-Content (Join-Path $raiz 'src\template-normas.html') -Raw -Encoding utf8
$html = $tpl.Replace('/*DATA*/{}', (Json 'normas.json')).Replace('/*SEI*/{}', (Json 'publicacoes_sei.json'))
[IO.File]::WriteAllText((Join-Path $raiz 'normas.html'), $html, (New-Object Text.UTF8Encoding($false)))
Write-Host "normas.html gerado ($([int]($html.Length/1024)) KB)"
