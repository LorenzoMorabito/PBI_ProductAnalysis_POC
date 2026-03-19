# A10P Promotional Core Semantic Model

## Scopo

Questo semantic model e' dedicato esclusivamente al mondo `Promotional / Channel Dynamics` e si basa unicamente sulle tabelle dello star schema contenute in:

- `C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\PBI A10P C7A IT SP GR - Channel Dynamics\star_schema_promotionl`

Obiettivo funzionale:

- semantic model monodominio `Promo`
- naming business allineato alle misure OAS realmente sostenibili con la fact attuale
- modello quarter-centric, pulito e senza oggetti UX composti
- isolamento completo dai mondi `Sales` e `Finance`

## Scelta temporale

La fact promo contiene piu snapshot per lo stesso `Calendar Quarter`.

Per ottenere un semantic model davvero quarter-centric, il modello importa solo l'ultimo snapshot disponibile per ciascun quarter di calendario, usando `dim_reporting_period.csv` come tabella di controllo.

Effetto pratico:

- quarter visibili nel modello: `17`
- righe fact importate nel semantic model: `23.339`
- esempio timeline: `Q1 2022 -> May 2022`, `Q2 2022 -> Aug 2022`, `Q3 2022 -> Nov 2022`, `Q4 2022 -> Feb 2023`

## Struttura del modello

Tabelle visibili:

- `Country`
- `Quarter`
- `Product`
- `Molecule`
- `Specialty`
- `Channel`
- `Feedback`
- `Promo`

Tabelle nascoste:

- `F_Promo`
- `B_ProductMolecule`

## Misure visibili

### Base

- `Investments`
- `Product Details`
- `Contact Number`
- `Mentions`
- `Weighted Calls`

### Share

- `% Share of Investments`
- `% Share of Voice`
- `Share of Contact Number`
- `SOV%`

### Positive Prescribing

- `Contact Number with intention to increase Rx`
- `% of Contact Number with intention to increase Rx`
- `Product Details with Positive Prescribing`
- `Contacts with Positive Prescribing`
- `Conversion rate - % of Calls converted in intention to prescribe`
- `Conversion rate - % of Contacts converted in intention to prescribe`

### Compare

- `Investments +/- vs PY`
- `Investments +/-% vs PY`
- `Product Details +/- vs PY`
- `Product Details +/-% vs PY`
- `Contact Number +/- vs PY`
- `Contact Number +/-% vs PY`
- `Mentions +/- vs PY`
- `Mentions +/-% vs PY`
- `Weighted Calls +/- vs PY`
- `Weighted Calls +/-% vs PY`
- `SOV% +/-% vs PY`

## Note tecniche

- Il modello e' quarter-centric per scelta esplicita di semanticizzazione, pur partendo da una fact con reporting snapshots.
- Le misure di share usano un perimetro di mercato basato su `ATC4`, mantenendo attivi i filtri di contesto su paese, specialty, channel e feedback.
- Il bridge prodotto-molecola e' presente per permettere slicing atomico per molecola.
- Il semantic model contiene solo star schema e misure core esplicite.
- Non include selector dinamici, switch periodali, ranking tables o custom slicer helpers.
- Restano fuori dal core le famiglie promo avanzate `Index`, `% Corp on total` e `% Market on total`, che richiedono una formalizzazione business aggiuntiva.

## File principali

- `definition/model.tmdl`
- `definition/relationships.tmdl`
- `definition/tables/F_Promo.tmdl`
- `definition/tables/Quarter.tmdl`
- `definition/tables/Promo.tmdl`
