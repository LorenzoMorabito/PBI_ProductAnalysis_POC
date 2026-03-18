# Modularity Area

Questa area raccoglie tutto cio che riguarda l'authoring modulare e la platform condivisa.

## Domini contenuti

- [pbi-finance-domain](./pbi-finance-domain)
  Domain source per i package finance.
- [pbi-marketing-domain](./pbi-marketing-domain)
  Domain source per i package marketing.
- [pbi-modular-platform](./pbi-modular-platform)
  Installer, quality checks, schemi e documentazione lifecycle.

## Stato attuale

Package attualmente catalogati:

- finance:
  - `finance_compare_mvp` `0.1.0`
- marketing:
  - `flex_metrics_table_mvp` `0.2.1`
  - `flex_table_flat_mvp` `0.2.0`

Capabilita oggi operative della platform:

- `list-modules`
- `validate-project`
- `install-module`
- `upgrade-module`
- `diff-module`
- `rollback-module`
- `set-data-source-path`
- `test-module`
- `test-project`
- `test-repo`
- `smoke-install`
- `Invoke-PbiModularity.ps1` wrapper CLI
- generator `new-module`

## Regola operativa

- i package source si sviluppano qui
- gli asset installati restano nei consumer sotto `powerbi-projects`
- il contract `core vs module` va rispettato prima di introdurre nuovi oggetti
