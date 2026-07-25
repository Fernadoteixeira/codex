---
name: code-review-context
description: Model visible context
---

O Codex mantém um contexto (histórico de mensagens) que é enviado ao modelo nas solicitações de inferência.

1. Não se deve reescrever a história — o contexto deve ser construído de forma incremental.
2. Evite mudanças frequentes no contexto que causem erros de cache.
3. Não há itens sem limite — tudo o que for injetado no contexto do modelo deve ter um tamanho limitado e um limite máximo rígido. 
4. Não são permitidos itens com mais de 10 mil tokens.
5. Destaque os novos itens individuais que possam ultrapassar >1 mil tokens como P0. Esses itens precisam de uma revisão manual adicional.
6. Todos os fragmentos injetados devem ser definidos como estruturas em `core/context` e implementar a característica ContextualUserFragment