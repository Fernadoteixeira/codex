## Instalação & Compilação

### Requisitos do sistema

| Requisito                   | Detalhes                                                        |
| --------------------------- | --------------------------------------------------------------- |
| Sistemas operacionais       | macOS 12+, Ubuntu 20.04+/Debian 10+, ou Windows 11 **via WSL2** |
| Git (opcional, recomendado) | 2.23+ para recursos integrados de PR                            |
| Memória RAM                 | Mínimo de 4 GB (8 GB recomendado)                               |

### DotSlash

A Release do GitHub também contém um arquivo [DotSlash](https://dotslash-cli.com/) para o Codex CLI chamado `codex`. O uso de um arquivo DotSlash permite fazer um commit leve no controle de versão para garantir que todos os colaboradores usem a mesma versão do executável, independentemente da plataforma usada no desenvolvimento.

### Compilar a partir do código-fonte

```bash
# Clone o repositório e navegue até a raiz do workspace Cargo.
git clone https://github.com/openai/codex.git
cd codex/codex-rs

# Instale o toolchain do Rust, se necessário.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add rustfmt
rustup component add clippy
# Instale ferramentas auxiliares usadas pelo justfile do workspace:
cargo install --locked just
# O DotSlash busca ferramentas de desenvolvimento fixadas, como o buildifier, no primeiro uso.
cargo install --locked dotslash
# Instale o nextest para o utilitário `just test`.
cargo install --locked cargo-nextest

# Compile o Codex.
cargo build

# Inicie a TUI com um prompt de exemplo.
cargo run --bin codex -- "explain this codebase to me"

# Após fazer alterações, use os auxiliares do justfile na raiz (o padrão é codex-rs):
just fmt
just fix -p <crate-que-voce-alterou>

# Execute os testes relevantes (específicos do projeto é mais rápido), por exemplo:
just test -p codex-tui
# `just test` executa a suíte de testes via nextest:
just test
# Evite `--all-features` em execuções locais de rotina porque isso aumenta o tempo
# de compilação e o uso de disco em `target/` ao compilar combinações de recursos adicionais.
```

## Rastreamento / Logs detalhados

O Codex é escrito em Rust, portanto ele respeita a variável de ambiente `RUST_LOG` para configurar seu comportamento de log.

A TUI registra diagnósticos em armazenamentos locais delimitados por padrão. Defina `log_dir` explicitamente para ativar um log em texto simples da TUI durante uma execução:

```bash
codex -c log_dir=./.codex-log
tail -F ./.codex-log/codex-tui.log
```

O modo não interativo (`codex exec`) tem como padrão `RUST_LOG=error`, mas as mensagens são exibidas diretamente no terminal, portanto não há necessidade de monitorar um arquivo separado.

Consulte a documentação do Rust sobre [`RUST_LOG`](https://docs.rs/env_logger/latest/env_logger/#enabling-logging) para obter mais informações sobre as opções de configuração.
