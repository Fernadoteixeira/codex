<p align="center"><strong>Codex CLI</strong> é um agente de programação da OpenAI que é executado localmente no seu computador.
<p align="center">
  <img src="https://github.com/openai/codex/blob/main/.github/codex-cli-splash.png" alt="Codex CLI splash" width="80%" />
</p>
</br>
Se você quiser o Codex no seu editor de código (VS Code, Cursor, Windsurf), <a href="https://developers.openai.com/codex/ide">instale-o no seu IDE.</a>
</br>Se você quiser ter a experiência do aplicativo para desktop, execute <code>o aplicativo Codex</code> ou acesse <a href="https://chatgpt.com/codex?app-landing-page=true">a página do aplicativo Codex</a>.
</br>Se você estiver procurando pelo <em>agente baseado na nuvem</em> da OpenAI, <strong>Codex Web</strong>, acesse <a href="https://chatgpt.com/codex">chatgpt.com/codex</a>.</p>

---

## Guia de Início Rápido

### Instalando e executando o Codex CLI

Execute o seguinte no Mac ou no Linux para instalar o Codex CLI:

```shell
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Execute o seguinte no Windows para instalar o Codex CLI:

```shell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Os instaladores independentes fazem o download a partir de `https://releases.openai.com/codex` por padrão e recorrem ao GitHub Releases caso o download de metadados ou recursos não esteja disponível. Para forçar o uso do GitHub Releases, defina `CODEX_INSTALLER_USE_RELEASES_OPENAI_COM` como `false` (`0` e `no` também são aceitos):

```shell
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_INSTALLER_USE_RELEASES_OPENAI_COM=false sh
```

```powershell
$env:CODEX_INSTALLER_USE_RELEASES_OPENAI_COM='false'; irm https://chatgpt.com/codex/install.ps1 | iex
```

O Codex CLI também pode ser instalado por meio dos seguintes gerenciadores de pacotes:

```shell
# Install using npm
npm install -g @openai/codex
```

```shell
# Install using Homebrew
brew install --cask codex
```

Em seguida, basta digitar `codex` para começar.

<details>
<summary>Você também pode acessar a <a href="https://github.com/openai/codex/releases/latest">versão mais recente no GitHub</a> e baixar o arquivo binário adequado para a sua plataforma.</summary>

Cada versão do GitHub contém vários executáveis, mas, na prática, você provavelmente vai querer um destes:

- macOS
  - Apple Silicon/arm64: `codex-aarch64-apple-darwin.tar.gz`
  - x86_64 (hardware mais antigo do Mac): `codex-x86_64-apple-darwin.tar.gz`
- Linux
  - x86_64: `codex-x86_64-unknown-linux-musl.tar.gz`
  - arm64: `codex-aarch64-unknown-linux-musl.tar.gz`

Cada arquivo contém uma única entrada com o nome da plataforma incorporado (por exemplo, `codex-x86_64-unknown-linux-musl`); portanto, é provável que você queira renomeá-la para `codex` após extraí-la.

</details>

### Como usar o Codex com seu plano do ChatGPT

Execute `codex` e selecione **Entrar com o ChatGPT**. Recomendamos que você faça login na sua conta do ChatGPT para usar o Codex como parte do seu plano Plus, Pro, Business, Edu ou Enterprise. [Saiba mais sobre o que está incluído no seu plano do ChatGPT](https://help.openai.com/en/articles/11369540-codex-in-chatgpt).

Você também pode usar o Codex com uma chave de API, mas isso requer [configuração adicional](https://developers.openai.com/codex/auth#sign-in-with-an-api-key).

## Documentos

- [**Codex Documentation**](https://developers.openai.com/codex)
- [**Contributing**](./docs/contributing.md)
- [**Installing & building**](./docs/install.md)
- [**Open source fund**](./docs/open-source-fund.md)

Este repositório está licenciado sob a licença [Licença Apache 2.0](LICENSE).
