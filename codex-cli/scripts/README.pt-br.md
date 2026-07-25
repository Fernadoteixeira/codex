# Lançamentos do npm

Use o auxiliar de preparação na raiz do repositório para gerar arquivos tar do npm para um lançamento. Para
Por exemplo, para instalar os pacotes da CLI, do proxy de respostas e do SDK da versão `0.6.0`:

```bash
./scripts/stage_npm_packages.py \
  --release-version 0.6.0 \
  --package codex \
  --package codex-responses-api-proxy \
  --package codex-sdk
```

Isso baixa os artefatos necessários do arquivo do pacote nativo e hidrata `vendor/` para
cada pacote e grava os arquivos tar em `dist/npm/`.

Quando `--package codex` é fornecido, o auxiliar de preparação cria o
`@openai/codex` pacote meta mais todas as variantes `@openai/codex` nativas da plataforma
que são posteriormente publicados sob tags de distribuição específicas para cada plataforma.

As invocações diretas `build_npm_package.py` ainda são úteis para pacotes específicos
depuração, mas os pacotes nativos esperam que `--vendor-src` aponte para um arquivo pré-hidratado
`vendor/` árvore. A embalagem de lançamento deve usar `scripts/stage_npm_packages.py`.
