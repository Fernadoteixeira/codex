Analise este PR e responda com uma mensagem final bem concisa, formatada em Markdown.

Deve haver um resumo das alterações (1 a 2 frases) e alguns pontos-chave, se necessário.

Em seguida, forneça a **avaliação** (1 a 2 frases, além de pontos-chave, em tom amigável).

Pontos a serem observados ao realizar a revisão:

## Princípios Gerais

- **Certifique-se de que o corpo da solicitação de pull explique a motivação por trás da alteração.** Se o autor não tiver feito isso, chame a atenção para esse ponto e, se achar que pode deduzir a motivação por trás da alteração, proponha o texto.
- O ideal é que o corpo do PR também inclua um breve resumo da alteração. No caso de pequenas alterações, o título do PR pode ser suficiente.
- Idealmente, cada PR deve abordar apenas um aspecto conceitual. Por exemplo, se um PR incluir tanto uma refatoração quanto a introdução de um novo recurso, recuse-o e sugira que a refatoração seja feita em um PR separado. Isso facilita o trabalho do revisor, já que as alterações de refatoração costumam ter um alcance amplo, mas são rápidas de revisar.
- Ao introduzir um novo código, fique atento a trechos que possam duplicar o código já existente. Ao identificá-los, proponha uma maneira de refatorar o código existente para que ele possa ser reutilizado.

## Organização do código

- Cada crate na área de trabalho Cargo em `codex-rs` tem uma finalidade específica: anote se você achar que o novo código não foi inserido no crate correto.
- Sempre que possível, tente manter a caixa `core` o menor possível. A lógica não essencial, mas compartilhada, costuma ser uma boa candidata para `codex-rs/common`.
- Fique atento a arquivos grandes e ofereça sugestões sobre como dividi-los em arquivos de tamanho mais razoável.
- Os arquivos Rust devem, em geral, ser organizados de forma que as partes públicas da API apareçam no início do arquivo e as funções auxiliares fiquem logo em seguida. Isso é análogo à estrutura da “pirâmide invertida”, amplamente utilizada no jornalismo.

## Asserções em testes

Verifique a igualdade dos objetos como um todo, em vez de fazer “comparações fragmentadas”, aplicando `assert_eq!()` a campos individuais.

Observe que os testes unitários também funcionam como “documentação executável”. Conforme mostrado no exemplo a seguir, as “comparações fragmentadas” costumam ser mais prolixas, oferecem menor cobertura e não são tão úteis quanto a documentação executável.

Por exemplo, suponha que você tenha a seguinte enumeração:

```rust
#[derive(Debug, PartialEq)]
enum Message {
    Request {
        id: String,
        method: String,
        params: Option<serde_json::Value>,
    },
    Notification {
        method: String,
        params: Option<serde_json::Value>,
    },
}
```

Este é um exemplo de uma comparação _fragmentada_:

```rust
// BAD: Piecemeal Comparison

#[test]
fn test_get_latest_messages() {
    let messages = get_latest_messages();
    assert_eq!(messages.len(), 2);

    let m0 = &messages[0];
    match m0 {
        Message::Request { id, method, params } => {
            assert_eq!(id, "123");
            assert_eq!(method, "subscribe");
            assert_eq!(
                *params,
                Some(json!({
                    "conversation_id": "x42z86"
                }))
            )
        }
        Message::Notification { .. } => {
            panic!("expected Request");
        }
    }

    let m1 = &messages[1];
    match m1 {
        Message::Request { .. } => {
            panic!("expected Notification");
        }
        Message::Notification { method, params } => {
            assert_eq!(method, "log");
            assert_eq!(
                *params,
                Some(json!({
                    "level": "info",
                    "message": "subscribed"
                }))
            )
        }
    }
}
```

Esta é uma comparação _aprofundada_:

```rust
// GOOD: Verify the entire structure with a single assert_eq!().

use pretty_assertions::assert_eq;

#[test]
fn test_get_latest_messages() {
    let messages = get_latest_messages();

    assert_eq!(
        vec![
            Message::Request {
                id: "123".to_string(),
                method: "subscribe".to_string(),
                params: Some(json!({
                    "conversation_id": "x42z86"
                })),
            },
            Message::Notification {
                method: "log".to_string(),
                params: Some(json!({
                    "level": "info",
                    "message": "subscribed"
                })),
            },
        ],
        messages,
    );
}
```

## Mais aspectos táticos do Rust a serem observados

- Não use `unsafe` (a menos que você tenha um motivo realmente, realmente bom, como usar diretamente a API de um sistema operacional e não exista nenhum wrapper seguro). Por exemplo, há casos em que é tentador usar `unsafe` para poder usar `std::env::set_var()`, mas isso, na verdade, `unsafe` e já causou condições de corrida em várias ocasiões. (Quando isso acontecer, encontre um mecanismo diferente das variáveis de ambiente para usar na configuração.)
- Incentive o uso de pequenas enums ou do padrão newtype no Rust, caso isso contribua para a legibilidade sem aumentar significativamente a carga cognitiva ou o número de linhas de código.
- Se você identificar oportunidades para que as alterações no diff utilizem um código mais idiomático em Rust, por favor, faça recomendações específicas. Por exemplo, dê preferência ao uso de expressões em vez de `return`.
- Ao modificar um arquivo `Cargo.toml`, certifique-se de que as listas de dependências permaneçam ordenadas alfabeticamente. Verifique também se uma nova dependência foi adicionada no local correto (por exemplo, `[dependencies]` em vez de `[dev-dependencies]`)

## Corpo da solicitação de pull

- Se a natureza da alteração parecer ter um componente visual (o que costuma ser o caso das alterações em `codex-rs/tui`), recomenda-se incluir uma captura de tela ou um vídeo para demonstrar a alteração, se for o caso.
- Recomenda-se fazer referências a issues e PRs existentes no GitHub, quando for o caso; no entanto, como você provavelmente não tem acesso à internet, talvez não seja possível ajudar nesse sentido.

# Informações de RP

{CODEX_ACTION_GITHUB_EVENT_PATH} contém o JSON que acionou este fluxo de trabalho do GitHub. Ele contém as referências `base` e `head` que definem este PR. Ambas as referências estão disponíveis localmente.
