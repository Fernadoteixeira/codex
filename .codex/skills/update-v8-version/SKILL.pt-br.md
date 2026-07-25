---
name: update-v8-version
description: Update Codex's pinned `v8` / `rusty_v8` versions, validate the release-candidate path, and investigate failed V8 canary or artifact builds. Use when asked to bump V8, update `rusty_v8` artifacts, prepare or validate a V8 release candidate, check `v8-canary`, or diagnose why a V8 version update no longer builds.
---

# Atualização para a versão V8

## Fluxo de trabalho principal

1. Leia `third_party/v8/README.md` e siga a sequência de atualização de versão. Trate
   esse documento como a fonte de referência do processo de lançamento.
2. Inspecione e atualize as superfícies de concreto do repositório que sustentam o pino:
   - `codex-rs/Cargo.toml`
   - `codex-rs/Cargo.lock`
   - `MODULE.bazel`
   - `third_party/v8/BUILD.bazel`
   - `third_party/v8/README.md`
   - o manifesto correspondente `third_party/v8/rusty_v8_<version>.sha256` quando o
     as demais entradas pré-definidas mudam
3. Mantenha os auxiliares de checksum existentes na cadeia:

   bash
   python3 .github/scripts/rusty_v8_bazel.py update-module-bazel
   python3 .github/scripts/rusty_v8_bazel.py check-module-bazel
   python3 -m unittest discover -s .github/scripts -p test_rusty_v8_bazel.py
   ```

4. Valide o caminho da versão candidata ao lançamento antes de ampliar o escopo do trabalho:
   - Prefiro verificar o resultado do `v8-canary` CI para o branch candidato ou PR
     quando houver uma, utilizando as ferramentas de verificação do GitHub ou `gh`, conforme o caso.
   - Se o CI não estiver disponível ou se o usuário tiver solicitado uma verificação apenas local, execute o
     a validação local mais próxima que seja viável para a superfície alterada e, digamos,
     de forma explícita que se trata de um substituto local, e não do Canary completo hospedado.
5. Se o caminho “canary” for aprovado, pare por aí. Resuma o resultado e incentive o
   o usuário deve confirmar as alterações propostas ou prosseguir com o fluxo de lançamento, conforme
   solicitado. Não publique tags, versões ou envios, a menos que o usuário tenha solicitado.

## Caminho de falha

Insira este caminho somente quando o canary ou o caminho de compilação local falhar.

1. Registre o alvo com falha, a tarefa do fluxo de trabalho e o primeiro erro que permite uma ação.
2. Compare a versão atualmente fixada com a versão de destino na seção relevante
   tag upstream ou SHA. Verifique ambos:
   - `denoland/rusty_v8`
   - código-fonte do V8 do upstream na versão do Bazel definida como padrão
3. Acompanhe as alterações relevantes para a compilação, em vez das mudanças gerais no código-fonte:
   - gerou alterações no layout de ligação
   - alterações na nomenclatura de arquivos ou ativos
   - Alterações no target do GN/Bazel
   - entradas personalizadas para libc++ / libc++abi / llvm-libc
   - Relações entre o sandbox e o recurso de compactação de ponteiros
   - trechos de patch em `patches/` que não se aplicam mais ou não correspondem mais ao código original
4. Rastreie cada delta com falha de volta até o gráfico de compilação do Codex:
   - `MODULE.bazel`
   - `third_party/v8/BUILD.bazel`
   - `.github/scripts/rusty_v8_bazel.py`
   - `.github/workflows/v8-canary.yml`
   - `.github/workflows/rusty-v8-release.yml`
5. Atualize apenas os componentes necessários para restaurar a compilação da versão de destino e
   contrato de artefato. Mantenha as explicações dos patches e as alterações na documentação próximas ao
   arquivos afetados.
6. Execute novamente a validação específica. Se o indicador ficar verde, volte ao modo normal
   fluxo de trabalho e concluir com um resumo conciso, além da etapa restante do lançamento.

## Relatórios

- Indique se a validação veio do serviço hospedado `v8-canary` ou de um local
  substituto.
- Distinguir “atualização de versão concluída” de “versão lançada”.
- Quando houver um bloqueio, informe o delta upstream relevante e o arquivo Codex afetado,
  e a próxima solução prática a ser testada.
