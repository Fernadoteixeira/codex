# Teste em ambiente remoto do Windows

Este teste de integração `test_codex` exclusivo do Bazel executa um fixture do servidor exec do Windows
baseia-se no Wine e implementa a chamada de ferramenta padrão e a execução remota
caminho.

## Executando o teste

```sh
bazel test \
  //codex-rs/core/tests/remote_env_windows:smoke-test \
  --test_output=errors
```

Não é necessário o Wine no sistema. Cada processo recebe um `WINEPREFIX` novo e isolado
wineserver.

## Limitações atuais

- O comportamento do ConPTY/TTY ainda não foi abordado.
- O Wine carrega objetos compartilhados e DLLs PE em tempo de execução; portanto, o host ainda deve
  forneça a versão da glibc declarada como compatível.
- A plataforma-alvo está intencionalmente limitada a x86-64 por uma questão de simplicidade. Ela pode ser ampliada
  se identificarmos algum comportamento específico da arquitetura aarch64 que valha a pena testar.
