# Core vs Feature Modules

Data decisione: `2026-03-17`

## Obiettivo

Definire in modo formale cosa deve vivere nel `semantic core` e cosa deve invece essere sviluppato come `feature module` installabile o come `consumer-specific asset`.

Questa decisione serve a evitare due problemi:

- crescita incontrollata del core con logiche UI o use-case specifiche
- sviluppo di moduli che in realta dipendono da oggetti che avrebbero dovuto stare nel core

## Regole di classificazione

### Entra nel core se

- e riusabile da piu report
- rappresenta logica semantica stabile del dominio
- e prerequisito comune per altri moduli
- non dipende da slicer UX-specifici, bookmark o logiche di pagina

### Diventa feature module se

- abilita un use-case analitico specifico
- introduce selector table, wrapper measure, helper table o page assets specifici
- ha un lifecycle autonomo
- puo essere installato o escluso senza rompere il core

### Resta consumer-specific se

- e costruito per un singolo report o una singola pagina
- nasce per UX, layout, bookmark, storytelling o formattazione molto specifica
- non ha riuso realistico cross-project

## Semantic core approvato

Oggetti che restano nel `Core`:

- facts:
  - `T_FCT_SALES_A10P`
  - `T_FCT_PROMO_A10P_CD`
  - `T_FCT_FIN`
- dimensions:
  - `T_DIM_COUNTRY`
  - `T_DIM_MOLECULE`
  - `T_DIM_ACT4`
  - `T_DIM_PRODUCT`
  - `T_DIM_MONTH`
  - `T_DIM_QUARTER`
  - `T_DIM_CORPORATION`
  - `T_DIM_SPECIALTY`
  - `T_DIM_CHANNELS`
- measure tables:
  - `Msr Sales`
  - `Msr Promo`
  - `Msr Fin`
- supporto tecnico:
  - `root_path`
  - culture metadata

Verdetto:

- il `Core` e il semantic contract minimo e riusabile del progetto
- ogni nuovo modulo deve dipendere solo da questo perimetro, salvo eccezioni documentate

## Feature modules approvati o candidati

### Gia esternalizzati

| Modulo | Stato | Dominio | Tipo |
| --- | --- | --- | --- |
| `finance_compare_mvp` | implementato | finance | semantic pack + page pack |
| `flex_metrics_table_mvp` | implementato | marketing | semantic pack + page pack |
| `flex_table_flat_mvp` | implementato | marketing | semantic pack + page pack |

### Consumer derivati gia allineati al contract

| Consumer | Ruolo | Note |
| --- | --- | --- |
| `20260317_Product_Analysis_FlexTable` | derived consumer | semantic model dedicato con moduli marketing installati |
| `20260317_UAT_001` | UAT derived consumer | installa moduli finance e marketing sopra una copia del core |

### Da esternalizzare dal modello originale

| Area | Oggetti principali | Verdetto |
| --- | --- | --- |
| Finance compare | `SwitchCompareMode (Finance)`, `Msr Fin Switch` | `MODULE` |
| Sales selector | `SwitchMeasureSelector (Sales)`, `Msr Sales Switch` | `MODULE` |
| Promo selector | `SwitchMeasureSelector (Promo)`, `Msr Promo Switch` | `MODULE` |
| Competitive selector | `SwitchCompetitiveMeasureSelector`, `SwitchCompetitiveMeasureCategory` | `MODULE` |
| TopN ranking | `TopN`, `TopN Corp`, `TopN Prod`, `TopMetric`, `TopByUnits`, `TopByUnitsMarketshare`, `SwitchTopByDimension`, `SwitchTopByMesure` | `MODULE` |
| Buckets | `Corporation Buckets`, `ColumnStructure`, `LegendCorp`, `LegendSlot Groupped ...`, `Msr Sales/Promo/Fin Buckets` | `MODULE` |
| Time/lag extension | `SwitchLagSelection`, `SwitchPeriodMode`, `Lambda`, `MaxLag`, `Msr Promo LP`, `Msr Fin LP` | `MODULE` |
| Target/deep dive | `Dim_Entity`, `MeasureSalesSwitch (Target)`, `MeasurePromo(Topn+Target+Others)`, `SwitchFocusMode`, `GroupBySpending` | `MODULE` |
| Presentation | `.Titles`, `.Colours`, `KpiColorLabel` | `MODULE_OR_CONSUMER` |
| Scatter presets | `ScatterPreset` | `CONSUMER_OR_MODULE` |

## Aree da non rimettere nel core

Oggetti che non devono rientrare nel `Core` salvo decisione architetturale esplicita:

- `TopN`
- `Buckets`
- `Switch*` guidati da UX
- `ScatterPreset`
- `.Titles`
- `.Colours`
- wrapper input `MOD_*`
- page assets PBIR dei moduli

## Decisioni puntuali

### `ScatterPreset`

Verdetto: `consumer-specific` per default.

Motivo:

- oggi guida una visualizzazione molto specifica
- non e ancora un modulo generalizzato
- va tenuto fuori dal `Core`

### `.Titles` e `.Colours`

Verdetto: `feature module` oppure `consumer-specific`, non `core`.

Motivo:

- dipendono da presentation logic
- non rappresentano semantica business stabile

### `T_DIM_SPECIALTY` e `T_DIM_CHANNELS`

Verdetto attuale: `core`

Motivo:

- sono dimensioni di dominio, non helper UI
- ma andranno rivalutate se in futuro esistera un `marketing-core` distinto da un `promo-domain-core`

## Regola operativa per i nuovi sviluppi

Prima di creare un nuovo oggetto, va classificato in uno di questi bucket:

- `core`
- `feature module`
- `consumer-specific`

Se la classificazione non e chiara, il default corretto e:

- non metterlo nel core
- trattarlo come modulo o asset consumer finche non emerge riuso reale
