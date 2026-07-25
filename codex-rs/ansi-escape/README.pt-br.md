# oai-codex-ansi-escape

Pequenas funções auxiliares que encapsulam funcionalidades de
<https://crates.io/crates/ansi-to-tui>:

```rust
pub fn ansi_escape_line(s: &str) -> Line<'static>
pub fn ansi_escape<'a>(s: &'a str) -> Text<'a>
```

Vantagens:

- `ansi_to_tui::IntoText` não está no escopo de toda a caixa TUI
- nós `panic!()` e registramos se `IntoText` retorna um `Err` e registramos isso para que
  quem faz a chamada não precisa se preocupar com isso
