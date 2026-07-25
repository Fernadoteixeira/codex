# Esquema JSON de configuração

Geramos um esquema JSON para `~/.codex/config.toml` a partir do tipo `ConfigToml`
e fazer o commit em `codex-rs/core/config.schema.json` para integração com o editor.

Ao alterar qualquer campo incluído em `ConfigToml` (ou tipos de configuração aninhados),
regenerar o esquema:

```
just write-config-schema
```
