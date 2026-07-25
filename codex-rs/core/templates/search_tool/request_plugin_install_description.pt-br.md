# Solicitar instalação de plugin/conector

Utilize esta ferramenta apenas para solicitar ao usuário que instale um plug-in ou conector conhecido da lista abaixo. A lista contém opções conhecidas que ainda não estão instaladas.

Utilize isso SOMENTE quando todas as condições a seguir forem verdadeiras:
- O usuário solicita explicitamente o uso de um plug-in ou conector específico que ainda não está disponível no contexto atual ou na lista ativa `tools`.
- `tool_search` não está disponível ou já foi chamado e não conseguiu localizar nem tornar a ferramenta solicitada chamável.
- O plug-in ou conector é um dos plug-ins ou conectores instaláveis conhecidos listados a seguir. Solicite a instalação apenas de plug-ins ou conectores desta lista.

Não utilize esta ferramenta para funcionalidades relacionadas, recomendações genéricas ou ferramentas que simplesmente pareçam úteis. Utilize-a apenas quando o usuário solicitar explicitamente o uso daquele plugin ou conector específico listado.

Plug-ins/conectores conhecidos disponíveis para instalação:
{{discoverable_tools}}

Fluxo de trabalho:

1. Verifique primeiro o contexto atual e a lista `tools` ativa. Se as ferramentas ativas no momento não forem relevantes e `tool_search` estiver disponível, só chame essa ferramenta depois que `tool_search` já tiver sido testada e não tiver encontrado nenhuma ferramenta relevante.
2. Compare a solicitação explícita do usuário com a lista de plug-ins/conectores conhecida acima. Só prossiga quando um dos plug-ins ou conectores listados corresponder exatamente à solicitação.
3. Se encontrarmos tanto conectores quanto plug-ins para instalar, use os plug-ins primeiro; só use os conectores se o plug-in correspondente estiver instalado, mas o conector não estiver.
4. Se um plugin ou conector for claramente adequado, chame `request_plugin_install` com:
   - `tool_type`: `connector` ou `plugin`
   - `action_type`: `install`
   - `tool_id`: ID exato da lista de plug-ins/conectores conhecidos acima
   - `suggest_reason`: motivo conciso, de uma linha, voltado para o usuário, explicando como este plug-in ou conector pode ajudar na solicitação atual
5. Após a conclusão do fluxo da solicitação:
   - Se o usuário tiver concluído o processo de instalação, continue realizando uma nova pesquisa ou utilizando o plug-in ou conector recém-disponibilizado
   - Se o usuário não tiver concluído, continue sem esse plug-in ou conector e não o solicite novamente, a menos que o usuário peça explicitamente por ele.

IMPORTANTE: NÃO execute esta ferramenta em paralelo com outras ferramentas.
