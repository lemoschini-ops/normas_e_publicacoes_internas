# Normas e publicações internas — UFSCar

Painel (página única, HTML) para consulta e acompanhamento de **atos normativos vigentes** da UFSCar
(<https://www.ufscar.br/atos-normativos-da-ufscar>) e de **publicações do SEI** relacionadas à pesquisa e inovação
(<https://sei.ufscar.br>, Publicações Eletrônicas), com filtros dinâmicos, busca por palavras-chave, indicadores e gráficos.

**Painel publicado:** <https://lemoschini-ops.github.io/normas_e_publicacoes_internas/>

## Atualização automática

O workflow `.github/workflows/atualizar-dados.yml` roda duas vezes ao dia (10h00 e 16h00, horário de Brasília), recoleta as
fontes, valida (se a coleta falhar ou vier mais de 20% menor, mantém os dados anteriores), regenera `normas.html` e faz commit
só se algo mudou. Também pode ser disparado manualmente na aba Actions.

## Conteúdo

| Caminho | O que é |
|---|---|
| `index.html` | Redireciona para o painel |
| `normas.html` | Painel pronto, com os dados embutidos |
| `src/template-normas.html` | Fonte do painel (`/*DATA*/{}` e `/*SEI*/{}` recebem os JSON) |
| `data/normas.json` | Atos normativos vigentes |
| `data/publicacoes_sei.json` | Publicações do SEI (unidades de pesquisa e palavras no resumo) |
| `data/atualizacao.json` | Resultado da última atualização |
| `scripts/coletar-normas.ps1` | Coleta no site de Atos Normativos |
| `scripts/coletar-publicacoes-sei.ps1` | Coleta nas Publicações Eletrônicas do SEI |
| `scripts/gerar-normas.ps1` | Gera `normas.html` |
| `scripts/atualizar.ps1` | Coleta + validação + geração |
| `scripts/agendar-windows.ps1` | Agenda a atualização no Agendador de Tarefas do Windows |

## Limites conhecidos

- Os "temas de pesquisa" são classificados por palavras da ementa; confira o ato no SEI antes de citar.
- A aba SEI não é o universo completo (~23 mil publicações): reúne as de unidades de pesquisa e as que têm palavras de pesquisa no resumo.
  Para ampliar, edite `$unidades` e `$termos` em `scripts/coletar-publicacoes-sei.ps1`.