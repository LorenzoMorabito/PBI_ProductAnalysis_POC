# Cana Finance OAS Parity Semantic Model

## Scopo

Questo semantic model e' dedicato esclusivamente al mondo `Finance` e si basa unicamente sulle tabelle dello star schema contenute in:

- `C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\PBI Cana Finance\star_schema_finance_int`

Obiettivo funzionale:

- copertura measure parity rispetto al perimetro finance identificato dai dump OAS
- naming business allineato a OAS
- modello pulito, monodominio, senza dipendenze dai mondi `Sales` e `Promo`

## Struttura del modello

Tabelle visibili:

- `Country`
- `Month`
- `Product`
- `Molecule`
- `Finance`

Tabelle nascoste:

- `F_Finance`
- `B_ProductMolecule`

## Misure visibili

### Base

- `ACT Mth`
- `PY Mth`
- `BDG Mth`
- `ACT Ytd`
- `PY Ytd`
- `BDG Ytd`
- `Actual Year`
- `Previous Year`
- `Budget`

### Compare

- `ACT Mth +/-% vs BDG`
- `ACT Mth +/-% vs PY`
- `ACT Ytd +/-% vs BDG`
- `ACT Ytd +/-% vs PY`

## Note tecniche

- Il modello e' month-centric, coerente con la grain della fact finance.
- `Budget` 2024 resta `null` dove il source non lo valorizza.
- Il bridge prodotto-molecola e' presente per permettere slicing atomico per molecola.
- Il semantic model contiene solo star schema e misure core esplicite.
- Non include selector, switch table, logiche dinamiche `PY/BDG`, `LP` o altri oggetti UX.
- I nomi delle misure esposte sono direttamente quelli business OAS.

## File principali

- `definition/model.tmdl`
- `definition/relationships.tmdl`
- `definition/tables/F_Finance.tmdl`
- `definition/tables/Finance.tmdl`
