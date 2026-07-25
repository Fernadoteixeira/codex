---
name: code-review
description: Run a final code review on a pull request
---

Utilize subagentes para revisar o código, empregando todas as habilidades do tipo “code-review-*”, exceto este orquestrador. Um subagente por habilidade. Passe o caminho completo da habilidade aos subagentes. Utilize o raciocínio xhigh.

Você deve devolver todas as questões de cada subagente. Você pode devolver um número ilimitado de resultados.
Use Markdown puro para relatar as conclusões.
Numere as conclusões para facilitar a consulta.
Cada resultado deve incluir um caminho de arquivo específico e um número de linha.

Se o usuário do GitHub responsável pela revisão for o proprietário da solicitação de pull, adicione a etiqueta `code-reviewed`.
Não deixe comentários no GitHub, a menos que seja solicitado explicitamente.
