# Crest — cópia de segurança

Este fork guarda uma cópia de [pauljoda/Crest](https://github.com/pauljoda/Crest).

- **Código:** o branch `main` (e os demais) é uma cópia exata do original,
  atualizada todo dia pelo workflow
  [`sync-upstream.yml`](.github/workflows/sync-upstream.yml).
  Nada daqui é apagado ou sobrescrito: se o original reescrever o histórico,
  a versão antiga fica.
- **Instaladores:** as releases estáveis (DMG, checksum e dSYM) são copiadas
  para as [releases deste fork](../../releases).
- **Workflows do original:** ficam desativados, e as Actions deste repositório
  estão restritas para que não rodem. Para fazer uma versão própria, reative-os
  em Settings → Actions e na aba Actions.

Este branch (`backup-sync`) é o padrão do repositório só para guardar o
workflow sem alterar o `main`.
