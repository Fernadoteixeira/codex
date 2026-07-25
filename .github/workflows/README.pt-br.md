# Estratégia de fluxo de trabalho

Os fluxos de trabalho neste diretório estão divididos de forma que as solicitações de pull recebam um sinal rápido e fácil de revisar, enquanto o `main` ainda passe por toda a verificação multiplataforma.

## Solicitações de pull

- `bazel.yml` é o principal caminho de verificação pré-fusão para o código Rust.
  Ele executa o Bazel `test` e o Bazel `clippy` nos alvos do Bazel compatíveis,
  incluindo os binários de teste em Rust gerados, necessários para a verificação de conformidade do código embutido `#[cfg(test)]`
  código.
- `rust-ci.yml` mantém as verificações de PR nativas do Cargo intencionalmente pequenas:
  - `cargo fmt --check`
  - `cargo shear`
  - `argument-comment-lint` no Linux, macOS e Windows
  - `tools/argument-comment-lint` testes de pacotes quando o lint ou sua configuração de fluxo de trabalho são alterados

## Pós-fusão em `main`

- O `bazel.yml` também é executado quando há envios para o `main`.
  Isso verifica novamente o caminho do Bazel mesclado e ajuda a manter os caches do BuildBuddy ativos.
- `rust-ci-full.yml` é o fluxo de trabalho completo de verificação nativo do Cargo.
  Isso mantém as verificações mais pesadas fora do fluxo de PR, mas ainda assim as valida após a fusão:
  - a matriz completa do Cargo `clippy`
  - a matriz completa do Cargo `nextest` por meio de fragmentos baseados em arquivos para cada plataforma
  - Arquivos do Windows ARM64 do Nextest compilados de forma cruzada no Windows x64 e, em seguida, reproduzidos em shards nativos do Windows ARM64
  - Compilações do Cargo com perfil de lançamento
  - multiplataforma `argument-comment-lint`
  - Testes do remote-env no Linux

## Regra geral

- Se uma verificação de compilação/teste/clippy puder ser expressa no Bazel, é preferível definir a versão no momento do PR como `bazel.yml`.
- Mantenha `rust-ci.yml` rápido o suficiente para que, normalmente, ele não seja o principal fator de latência do PR.
- Reserve `rust-ci-full.yml` para a cobertura nativa do Cargo em aplicações de grande porte, que o Bazel ainda não substitui.
