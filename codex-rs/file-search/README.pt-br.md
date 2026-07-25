# Pesquisar arquivo codex

Ferramenta de busca rápida e aproximada de arquivos para o Codex.

Utiliza o <https://crates.io/crates/ignore> nos bastidores (que é o que o `ripgrep` usa) para percorrer um diretório (respeitando `.gitignore`, etc.) para gerar a lista de arquivos a serem pesquisados e, em seguida, usa <https://crates.io/crates/nucleo-matcher> para realizar uma correspondência aproximada entre o `PATTERN` fornecido pelo usuário e o corpus.
