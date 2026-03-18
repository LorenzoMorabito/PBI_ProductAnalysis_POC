# A10P Sales Market Core Semantic Model

## Scopo

Questo semantic model e' dedicato esclusivamente al mondo `Sales` e si basa unicamente sulle tabelle dello star schema contenute in:

- `C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\PBI A10P C07A IT SP GR\star_schema_sales`

Obiettivo funzionale:

- semantic model monodominio `Sales`
- naming business allineato alle famiglie OAS realmente supportate dalla fact corrente
- modello quarter-centric, coerente con la grain del source
- assenza di switch, selector, slicer composti o altri oggetti UX

## Struttura del modello

Tabelle visibili:

- `Country`
- `Sector`
- `Quarter`
- `Diagnosis`
- `Product`
- `Molecule`
- `Sales`

Tabelle nascoste:

- `F_Sales`
- `B_ProductMolecule`

## Misure visibili

### Base

- `Units`
- `Values`
- `Units 3MM`
- `Values 3MM`

### Share

- `Units MS%`
- `Values MS%`
- `Units EI`
- `Values EI`

### Compare

- `Units +/-% vs PY`
- `Values +/-% vs PY`
- `Units +/-% vs PP`
- `Values +/-% vs PP`

### YTD

- `Units YTD`
- `Values YTD`
- `Units YTD +/-% vs PY`
- `Values YTD +/-% vs PY`

### MAT

- `Units MAT`
- `Values MAT`
- `Units MAT +/-% vs PY`
- `Values MAT +/-% vs PY`

## Note tecniche

- Il modello e' quarter-centric perche' la fact sorgente e' gia' aggregata per trimestre.
- `Units 3MM` e `Values 3MM` coincidono con il trimestre selezionato: nella sorgente attuale il `3MM` e' rappresentato dal quarter aggregate.
- `MS%` ed `EI` sono stati esplicitati in famiglie `Units` e `Values` per evitare selector dinamici.
- Il bridge prodotto-molecola e' presente per permettere slicing atomico per molecola.
- Il semantic model contiene solo star schema e misure core esplicite.
- Restano fuori scope, per mancanza di supporto nella fact corrente, i perimetri `Sales LE`, `PPG`, `Avg Price`, `Price/Volume/Mix`, `Brand/Generics`, `Region/Channel`, `Hospital/Retail` e gli scope interni `SELL IN / SELL OUT`.

## File principali

- `definition/model.tmdl`
- `definition/relationships.tmdl`
- `definition/tables/F_Sales.tmdl`
- `definition/tables/Sales.tmdl`
