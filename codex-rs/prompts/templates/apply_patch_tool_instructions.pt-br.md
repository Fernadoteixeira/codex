## `apply_patch`

Use o comando do shell `apply_patch` para editar arquivos.
A linguagem do seu patch é um formato diff simplificado e orientado a arquivos, projetado para ser fácil de analisar e seguro de aplicar. Você pode pensar nela como um “envelope” de alto nível:

*** Início do patch
[ uma ou mais seções do arquivo ]
*** Fim do patch

Dentro desse escopo, você tem uma sequência de operações com arquivos.
Você DEVE incluir um cabeçalho para especificar a ação que está realizando.
Cada operação começa com um dos três cabeçalhos:

*** Adicionar arquivo: <path> - cria um novo arquivo. Cada linha seguinte é uma linha + (o conteúdo inicial).
*** Excluir arquivo: <path> - excluir um arquivo existente. Não há nada a seguir.
*** Atualizar arquivo: <path> - aplicar o patch em um arquivo existente no local (opcionalmente com renomeação).

Pode ser seguido imediatamente por *** Ir para: <new path>, caso queira renomear o arquivo.
Em seguida, um ou mais “trechos”, cada um deles precedido por @@ (opcionalmente seguido por um cabeçalho de trecho).
Dentro de um bloco, cada linha começa com:

Para obter instruções sobre [context_before] e [context_after]:
- Por padrão, exiba 3 linhas de código imediatamente acima e 3 linhas imediatamente abaixo de cada alteração. Se uma alteração estiver a menos de 3 linhas de uma alteração anterior, NÃO duplique as linhas [context_after] da primeira alteração nas linhas [context_before] da segunda alteração.
- Se três linhas de contexto não forem suficientes para identificar de forma exclusiva o trecho de código dentro do arquivo, use o operador @@ para indicar a classe ou função à qual o trecho pertence. Por exemplo, poderíamos ter:
@@ classe BaseClass
[3 linhas de contexto preliminar]
- [código antigo]
+ [new_code]
[3 linhas de contexto posterior]

- Se um bloco de código for repetido tantas vezes em uma classe ou função a ponto de nem mesmo uma única instrução `@@` e três linhas de contexto conseguirem identificar de forma exclusiva o trecho de código, você pode usar várias instruções `@@` para saltar para o contexto correto. Por exemplo:

@@ classe BaseClass
@@    def method():
[3 linhas de contexto preliminar]
- [código antigo]
+ [new_code]
[3 linhas de contexto posterior]

A definição gramatical completa está abaixo:
Patch := Begin { FileOp } End
Begin := "*** Início do patch" NEWLINE
End := "*** Fim do patch" NEWLINE
FileOp := AdicionarArquivo | ExcluirArquivo | AtualizarArquivo
AddFile := "*** Adicionar arquivo: " path NEWLINE { "+" line NEWLINE }
DeleteFile := "*** Excluir arquivo: " caminho NEWLINE
UpdateFile := "*** Arquivo de atualização: " caminho NEWLINE [ MoveTo ] { Hunk }
MoveTo := "*** Mover para: " newPath NEWLINE
Hunk := "@@" [ cabeçalho ] NEWLINE { HunkLine } [ "*** Fim do arquivo" NEWLINE ]
HunkLine := (" " | "-" | "+") texto NEWLINE

Um patch completo pode combinar várias operações:

*** Início do patch
*** Adicionar arquivo: hello.txt
+Olá, mundo
*Arquivo de atualização: src/app.py
*** Mover para: src/main.py
@@ def greet():
-print("Oi")
+print("Olá, mundo!")
*** Excluir arquivo: obsolete.txt
*** Fim do patch

É importante lembrar:

- Você deve incluir um cabeçalho indicando a ação pretendida (Adicionar/Excluir/Atualizar)
- É necessário antepor `+` às novas linhas, mesmo ao criar um novo arquivo
- As referências a arquivos só podem ser relativas, NUNCA ABSOLUTAS.

Você pode chamar o `apply_patch` da seguinte maneira:

```
shell {"command":["apply_patch","*** Begin Patch\n*** Add File: hello.txt\n+Hello, world!\n*** End Patch\n"]}
```
