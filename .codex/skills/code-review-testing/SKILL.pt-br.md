---
name: code-review-testing
description: Test authoring guidance
---

Para alterações no agente, dê preferência aos testes de integração em vez dos testes unitários. Os testes de integração estão em `core/suite` e utilizam `test_codex` para configurar uma instância de teste do Codex.

Recursos que alteram a lógica do agente DEVEM incluir um teste de integração:
- Forneça uma lista das principais alterações na lógica e dos comportamentos visíveis ao usuário que precisam ser testados.

Se forem necessários testes unitários, coloque-os em um arquivo de teste específico (*_tests.rs).
Evite funções destinadas exclusivamente a testes na implementação principal.

Verifique se já existem funções auxiliares que tornem os testes mais eficientes e legíveis.
