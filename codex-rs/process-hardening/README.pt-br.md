# codex-processo-de-tempra

Este crate fornece `pre_main_hardening()`, que foi projetado para ser chamado antes de `main()` (usando `#[ctor::ctor]`) a fim de executar várias etapas de endurecimento de processos, tais como

- desativando os core dumps
- Desativando o ptrace attach no Linux e no macOS
- remover variáveis de ambiente perigosas, como `LD_PRELOAD` e `DYLD_*`
