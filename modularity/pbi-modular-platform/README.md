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
- `docs/`
  note di lifecycle

## Stato attuale

Capabilita implementate:

- `list-modules`
- `validate-project`
- `install-module`
- `set-data-source-path`
- `list-rules`
- `test-module`
- `test-project`
- `test-repo`
- `smoke-install`

Capabilita non ancora completate:

- `upgrade-module` end-to-end
- rollback esplicito dei moduli
- diff guidato tra versione installata e sorgente

## Posizionamento nella repo

Questa cartella vive sotto `modularity/` e rappresenta la platform condivisa del workspace corrente.

Resta anche il candidato naturale a futura repository dedicata, ma oggi e gia un componente operativo e non solo uno scaffold.
