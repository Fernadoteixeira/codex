# Visão geral
Este diretório é uma coleção de testes de ponta a ponta para a especificação apply-patch, concebida para ser facilmente portável para outras linguagens ou plataformas.


# Especificações
Cada caso de teste corresponde a um diretório, composto pelo estado inicial (input/), a operação de patch (patch.txt) e o estado final esperado (expected/). Essa estrutura foi projetada para manter os testes simples (ou seja, testar exatamente um patch por vez), ao mesmo tempo em que oferece flexibilidade suficiente para testar qualquer operação específica em vários arquivos.

Veja como ficaria isso em um caso de teste simples do tipo “apply-patch” para criar um novo arquivo:

```
001_add/
  input/
    foo.md
  expected/
    foo.md
    bar.md
  patch.txt
```
