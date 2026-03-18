# Repository Topology

La repository e ora organizzata in tre aree di dominio esplicite.

## Topologia corrente

- `powerbi-projects`
  Progetti `PBIP` attivi, semantic model, report e `module-config`.
- `modularity`
  Package source di dominio, installer, quality checks, schemi e lifecycle.
- `repository-health`
  Monitoring Git, workflow CI dedicati e configurazione della persistenza storica.

## Mappa dei progetti attivi

- `powerbi-projects/20260227_Product_Analysis.*`
  Consumer storico completo.
- `powerbi-projects/20260227_Product_Analysis_Core.*`
  Baseline pulita del semantic core.
- `powerbi-projects/20260317_Product_Analysis_FlexTable.*`
  Consumer derivato con semantic model dedicato e moduli FlexTable.
- `powerbi-projects/20260317_UAT_001.*`
  Progetto UAT validato con installazione progressiva dei moduli.

## Mappa dei package source attivi

- `modularity/pbi-finance-domain/packages/finance_compare_mvp`
- `modularity/pbi-marketing-domain/packages/flex_metrics_table_mvp`
- `modularity/pbi-marketing-domain/packages/flex_table_flat_mvp`

## Mappa della platform tecnica

- `modularity/pbi-modular-platform/installer`
- `modularity/pbi-modular-platform/testing`
- `modularity/pbi-modular-platform/docs`
- `modularity/pbi-modular-platform/schemas`

## Mappa del monitoring Git

- `repository-health/analyzer.ps1`
- `repository-health/config.json`
- `repository-health/scripts/*`
- branch dati dedicato `repo-health-data`

## Regole operative

- il `package source` vive nella domain area
- gli asset installati restano nel consumer dentro `powerbi-projects`
- il `Core` non deve ricevere asset `MOD_*`
- i consumer derivati con moduli devono avere semantic model dedicato
- gli upgrade dei moduli devono restare espliciti e versionati

## Direzione futura

Il layout a tre aree e il contratto operativo ufficiale.

Lo split in repository distinte resta un obiettivo successivo e va fatto solo quando saranno stabili:

- contract `core vs module`
- installer e lifecycle dei moduli
- workflow di rilascio e upgrade
