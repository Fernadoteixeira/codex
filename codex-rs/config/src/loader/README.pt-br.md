# `codex-config` carregador

Este módulo é o local padrão para **carregar e descrever as camadas de configuração do Codex** (configuração do usuário, substituições de CLI/sessão, configuração gerenciada na nuvem, configuração gerenciada e preferências gerenciadas por MDM) e para gerar:

- Uma configuração TOML **efetivamente mesclada**.
- Metadados de **origens por chave** (qual camada “prevalece” para uma determinada chave).
- **Versões por camada** (impressões digitais estáveis) utilizadas para concorrência otimista / detecção de conflitos.

## Área pública

Exportado de `codex_config::loader`:

- `load_config_layers_state(fs, codex_home, cwd_opt, cli_overrides, options, thread_config_loader) -> ConfigLayerStack`
- `ConfigLayerStack`
  - `effective_config() -> toml::Value`
  - `origins() -> HashMap<String, ConfigLayerMetadata>`
  - `layers_high_to_low() -> Vec<ConfigLayer>`
  - `with_user_config(user_config) -> ConfigLayerStack`
- `ConfigLayerEntry` (uma camada `{name, config, version, disabled_reason}`; `name` contém os metadados de origem)
- `ConfigLoadOptions` (comportamento de carga voltado para o usuário, como validação rigorosa da configuração)
- `LoaderOverrides` (ganchos de teste/substituição para fontes de configuração gerenciadas)
- `merge_toml_values(base, overlay)` (função auxiliar pública usada em outro lugar)

## Modelo de camadas

A precedência é **a regra de cima prevalece sobre a de baixo**:

1. `LegacyManagedConfigTomlFromMdm` (fornecido pelo MDM `managed_config.toml`, embora esteja sendo descontinuado)
2. `LegacyManagedConfigTomlFromFile` (`managed_config.toml`, enquanto estiver sendo descontinuado)
3. `SessionFlags` (substituições da CLI, aplicadas conforme as gravações TOML com caminho pontilhado)
4. `Project` config (`.codex/config.toml`)
5. `User` configuração do perfil, quando houver
6. `User` config (`config.toml`)
7. `EnterpriseManaged` camadas de pacotes de configuração gerenciadas na nuvem
8. `System` config (`/etc/codex/config.toml` ou o caminho de configuração do sistema do Windows)

`ConfigLayerStack` armazena as camadas internamente na ordem inversa: a mais baixa
a precedência mais alta vem por último, a mais baixa por primeiro; assim, as camadas posteriores substituem as anteriores
camadas quando dobrado. As entradas de configuração de thread fornecidas por `thread_config_loader` são
inseridos de acordo com a precedência traduzida `ConfigLayerSource`.

As camadas com um `disabled_reason` ainda são exibidas na interface do usuário, mas são ignoradas quando
calculando a configuração efetiva e os metadados de origens. É isso que
`ConfigLayerStack::effective_config()` implementos.

## Uso típico

A maioria dos usuários deseja a configuração efetiva, além dos metadados:

```rust
use codex_config::LoaderOverrides;
use codex_config::NoopThreadConfigLoader;
use codex_config::loader::load_config_layers_state;
use codex_exec_server::LOCAL_FS;
use codex_utils_absolute_path::AbsolutePathBuf;
use toml::Value as TomlValue;

let cli_overrides: Vec<(String, TomlValue)> = Vec::new();
let cwd = AbsolutePathBuf::current_dir()?;
let layers = load_config_layers_state(
    LOCAL_FS.as_ref(),
    &codex_home,
    Some(cwd),
    &cli_overrides,
    LoaderOverrides::default(),
    &NoopThreadConfigLoader,
).await?;

let effective = layers.effective_config();
let origins = layers.origins();
let layers_for_ui = layers.layers_high_to_low();
```

## Layout interno

A implementação é dividida por área de interesse:

- `state.rs`: tipos públicos (`ConfigLayerEntry`, `ConfigLayerStack`) + métodos de conveniência merge/origins.
- `layer_io.rs`: leitura das entradas `config.toml`, configuração gerenciada e preferências gerenciadas.
- `overrides.rs`: As substituições de caminho pontilhado da CLI → camada de “sinalizadores de sessão” do TOML.
- `merge.rs`: fusão recursiva de TOML.
- `fingerprint.rs`: hash estável por camada e percurso das origens por chave.
- `macos.rs`: integração de preferências gerenciadas (somente no macOS).
