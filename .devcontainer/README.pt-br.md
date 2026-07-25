# Desenvolvimento em contêineres

Oferecemos duas opções de contêineres:

- `devcontainer.json` mantém a configuração atual dos colaboradores do Codex para trabalhar neste repositório.
- `devcontainer.secure.json` adiciona um perfil voltado para o cliente com controles mais rigorosos da rede de saída.

## Perfil do colaborador do Codex

Use `devcontainer.json` ao desenvolver o próprio Codex. Trata-se do mesmo contêiner arm64 leve que já existe no repositório.

## Perfil seguro do cliente

Use `devcontainer.secure.json` quando desejar um perfil de tempo de execução mais restrito para executar o Codex dentro de um contêiner de projeto:

- instala o Codex CLI e as ferramentas comuns de compilação
- instala o bubblewrap no modo setuid para a sandbox do Codex no Linux
- desativa os perfis externos do seccomp e do AppArmor do Docker para que o bubblewrap possa criar a sandbox interna do Codex
- ativa a inicialização do firewall com uma política de tráfego de saída baseada em lista de permissões
- bloqueia o IPv6 por padrão, de modo que a lista de permissões não pode ser contornada por meio de rotas AAAA
- requer `NET_ADMIN` e `NET_RAW` para que o firewall possa ser instalado na inicialização

Esse perfil mantém as restrições de rede mais rígidas isoladas ao caminho do cliente, em vez de alterar o contêiner padrão do colaborador do Codex.

Inicie-o pela CLI com:

```bash
devcontainer up --workspace-folder . --config .devcontainer/devcontainer.secure.json
```

No VS Code, selecione **Dev Containers: Abrir pasta no contêiner...** e selecione `.devcontainer/devcontainer.secure.json`.

## Docker

Para compilar a imagem do colaborador localmente para x64 e, em seguida, executá-la com o repositório montado em `/workspace`:

```shell
CODEX_DOCKER_IMAGE_NAME=codex-linux-dev
docker build --platform=linux/amd64 -t "$CODEX_DOCKER_IMAGE_NAME" ./.devcontainer
docker run --platform=linux/amd64 --rm -it -e CARGO_TARGET_DIR=/workspace/codex-rs/target-amd64 -v "$PWD":/workspace -w /workspace/codex-rs "$CODEX_DOCKER_IMAGE_NAME"
```

Observe que `/workspace/target` conterá os binários compilados para a plataforma do seu host; portanto, incluímos `-e CARGO_TARGET_DIR=/workspace/codex-rs/target-amd64` no comando `docker run` para que os binários compilados dentro do seu contêiner sejam gravados em um diretório separado.

Para arm64, especifique `--platform=linux/arm64` em vez de `docker build` e `docker run`.

Atualmente, o colaborador `Dockerfile` funciona tanto para o Linux x64 quanto para o arm64, embora você precise executar `rustup target add x86_64-unknown-linux-musl` por conta própria para instalar a cadeia de ferramentas musl para x64.

As opções de perfil seguro, seccomp e AppArmor são necessárias quando se deseja que a sandbox bubblewrap do Codex seja executada dentro do Docker como o usuário devcontainer (não root). Sem elas, o perfil de tempo de execução padrão do Docker pode bloquear a configuração do namespace do bubblewrap antes que o filtro seccomp do próprio Codex seja instalado. Isso mantém a flexibilização do Docker explícita no perfil destinado a executar o Codex dentro de um contêiner de projeto, enquanto o perfil padrão de colaborador permanece leve.
