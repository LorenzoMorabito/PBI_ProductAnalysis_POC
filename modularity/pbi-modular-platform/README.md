# PBI Modular Platform

Platform tecnica condivisa per package Power BI modulari.

## Responsabilita attuali

- installazione dei package nei consumer `PBIP`
- quality checks su moduli, progetti e repository
- schemi JSON per manifest e installed metadata
- contract architetturale `core vs module`
- documentazione lifecycle e workflow

## Componenti principali

- `installer/`
  entry point PowerShell e servizi di installazione
- `testing/`
  quality framework e smoke checks
- `schemas/`
  contratti JSON di manifest e metadata installativi
- `config/`
  soglie governance e integrazione repo-health
- `scaffolding/`
  generator per nuovi moduli
- `docs/`
  note di lifecycle e design architetturali

## Stato attuale

Capabilita implementate:

- `list-modules`
- `validate-project`
- `install-module`
- `upgrade-module`
- `diff-module`
- `rollback-module`
- `suggest-bindings`
- `list-binding-profiles`
- `set-data-source-path`
- `list-rules`
- `test-module`
- `test-project`
- `test-repo`
- `smoke-install`
- `Invoke-PbiModularity.ps1`
- `new-module`

Governance implementata:

- contract manifest governato con `type`, `classification`, `dependencies`, `semanticImpact`
- stato installato versionato con footprint, semantic objects e metriche impatto
- snapshot pre-write e rollback esplicito per modulo
- hook post-install verso `repository-health`
- gate `repository-health` basato su regressione rispetto al baseline pre-operazione
- warning/fail su moduli pesanti tramite config dedicata

Guided binding implementato:

- `bindingContract` opzionale nel manifest per moduli cross-domain
- discovery dei candidati da semantic model target
- suggestioni automatiche per measure e column bindings
- profili di binding salvati nel consumer sotto `module-config/.../mapping-profiles`
- supporto CLI a `-Interactive`, `-AcceptSuggested`, `-BindingProfileId`, `-SaveBindingProfileAs`

Design evolutivi documentati:

- [docs/lifecycle.md](./docs/lifecycle.md)
- [docs/interactive-binding-design.md](./docs/interactive-binding-design.md)

## Posizionamento nella repo

Questa cartella vive sotto `modularity/` e rappresenta la platform condivisa del workspace corrente.

Resta anche il candidato naturale a futura repository dedicata, ma oggi e gia un componente operativo e non solo uno scaffold.
