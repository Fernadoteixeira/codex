# codex-git-utils

Ferramentas para interagir com o Git, incluindo a aplicação de patches. O crate também
apresenta uma API básica e leve para diretórios internos que utilizam exclusivamente o Git
como um mecanismo de diferencial reinicializável: `ensure_git_baseline_repository` preserva um
utilizável `root/.git` linha de base ou cria uma quando ela estiver ausente ou inutilizável,
`reset_git_repository` substitui `root/.git` por uma linha de base nova com um único commit,
e `diff_since_latest_init` retorna as alterações no arquivo estruturado, além de um
diferenças entre essa linha de base e o conteúdo atual do diretório.

```rust,no_run
use std::path::Path;

use codex_git_utils::{apply_git_patch, ApplyGitRequest};

let repo = Path::new("/path/to/repo");

// Apply a patch (omitted here) to the repository.
let request = ApplyGitRequest {
    cwd: repo.to_path_buf(),
    diff: String::from("...diff contents..."),
    revert: false,
    preflight: false,
};
let result = apply_git_patch(&request)?;
```
