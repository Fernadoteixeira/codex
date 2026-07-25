---
name: test-tui
description: Guide for testing Codex TUI interactively
---

Você pode iniciar e usar o Codex TUI para verificar as alterações. 

Observações importantes:

Comece de forma interativa.
Sempre defina RUST_LOG="trace" ao iniciar o processo.
Passe o argumento `-c log_dir=<some_temp_dir>` para que os registros sejam gravados em um diretório específico, a fim de facilitar a depuração.
Ao enviar uma mensagem de teste por meio de programação, envie primeiro o texto e, em seguida, envie a tecla Enter em uma operação de gravação separada (não envie o texto + Enter de uma só vez).
Use o alvo `just codex` para executar - `just codex -c ...`
