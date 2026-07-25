# Configuração

Para instruções básicas de configuração, consulte [esta documentação](https://developers.openai.com/codex/config-basic).

Para instruções avançadas de configuração, consulte [esta documentação](https://developers.openai.com/codex/config-advanced).

Para uma referência completa de configuração, consulte [esta documentação](https://developers.openai.com/codex/config-reference).

## Hooks do ciclo de vida

Administradores podem definir a chave de nível superior `allow_managed_hooks_only = true` no arquivo `requirements.toml` para ignorar configurações de hooks do usuário, projeto e sessão, enquanto continuam permitindo hooks gerenciados a partir das camadas de requisitos e configurações gerenciadas. Esta configuração só é suportada no `requirements.toml`; colocá-la no `config.toml` não ativa o modo de apenas hooks gerenciados.
