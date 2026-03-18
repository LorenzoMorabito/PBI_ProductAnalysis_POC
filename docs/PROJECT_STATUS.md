# Project Status

Data aggiornamento: `2026-03-18`

## Sintesi esecutiva

La repository e oggi organizzata in tre aree operative:

- `powerbi-projects`
- `modularity`
- `repository-health`

Lo stato generale e `operativo e coerente`.

Verifiche eseguite sullo stato corrente:

- `test-project` sui 4 progetti `PBIP` versionati: `OK`
- `test-repo -FailOnError`: `OK`
- `repository-health/analyzer.ps1 -Mode local`: `WARN` atteso, nessun file vietato

## Stato dei progetti Power BI

| Progetto | Ruolo | Semantic model | Moduli installati | Stato quality |
| --- | --- | --- | --- | --- |
| `20260227_Product_Analysis` | consumer storico completo | dedicato, esteso, consumer-specific | nessuno gestito via `module-config` | `OK` |
| `20260227_Product_Analysis_Core` | baseline pulita | core governato | nessuno | `OK` |
| `20260317_Product_Analysis_FlexTable` | consumer derivato | dedicato, derivato dal core | `flex_metrics_table_mvp`, `flex_table_flat_mvp` | `OK` |
| `20260317_UAT_001` | progetto UAT | dedicato, derivato dal core | `finance_compare_mvp`, `flex_metrics_table_mvp`, `flex_table_flat_mvp` | `OK` |

## Stato del semantic core

Perimetro: [20260227_Product_Analysis_Core.pbip](../powerbi-projects/20260227_Product_Analysis_Core.pbip)

Stato attuale:

- `15` tabelle
- `15` relazioni
- `0` relazioni `AutoDetected`
- nessuna tabella `MOD_*`
- artefatti `Auto Date/Time` rimossi

Nota strutturale:

- la relazione `REL_MOLECULE_PRODUCT` resta `OneToOne` con `BothDirections` per compatibilita con Power BI Desktop

## Stato del progetto consumer originale

Perimetro: [20260227_Product_Analysis.pbip](../powerbi-projects/20260227_Product_Analysis.pbip)

Stato attuale:

- `66` tabelle nel semantic model
- `1` pagina report versionata
- contiene logiche non-core come `Switch*`, `TopN`, `Buckets`, `.Titles`, `.Colours`, `ScatterPreset`
- resta il riferimento del consumer storico completo, non del semantic core

## Stato dei consumer derivati

### Product Analysis FlexTable

Perimetro: [20260317_Product_Analysis_FlexTable.pbip](../powerbi-projects/20260317_Product_Analysis_FlexTable.pbip)

Stato attuale:

- `22` tabelle nel semantic model
- `2` pagine report
- usa semantic model dedicato
- installa:
  - `flex_metrics_table_mvp` `0.2.1`
  - `flex_table_flat_mvp` `0.2.0`

### UAT 001

Perimetro: [20260317_UAT_001.pbip](../powerbi-projects/20260317_UAT_001.pbip)

Stato attuale:

- `25` tabelle nel semantic model
- `4` pagine report
- rappresenta il primo giro UAT completato
- installa:
  - `finance_compare_mvp` `0.1.0`
  - `flex_metrics_table_mvp` `0.2.1`
  - `flex_table_flat_mvp` `0.2.0`

## Stato della modularity area

Package source pubblicati nel catalogo:

- `finance_compare_mvp`
- `flex_metrics_table_mvp`
- `flex_table_flat_mvp`

Stato della platform:

- installer PowerShell operativo
- quality checks operativi
- contract architetturale eseguibile
- `upgrade-module` ancora non implementato end-to-end

## Stato del framework repository health

Perimetro: [repository-health](../repository-health)

Stato attuale:

- workflow `PR`, `push`, `schedule` presenti
- persistenza `Level 2` attiva con branch `repo-health-data`
- analyzer locale funzionante
- nessun file vietato rilevato nello stato corrente

Warning corrente noto:

- largest current file `1.69 MB`, sopra la soglia warning `1 MB`

Questo warning non blocca il framework e non rappresenta un errore critico.

## Verdetto

Il workspace e in uno stato coerente con il layout a tre aree:

- `powerbi-projects` contiene i consumer e i semantic model attivi
- `modularity` contiene i package source e la platform
- `repository-health` contiene il monitoring Git e la persistenza storica

Le prossime evoluzioni architetturali sensate restano:

1. lifecycle esplicito di `upgrade-module`
2. eventuale split finale in repo distinte quando il contract sara stabile
