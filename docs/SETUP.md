# Setup

## Prerequisiti

- Power BI Desktop con supporto `PBIP`, `TMDL` ed `Enhanced report format`
- Git
- PowerShell 7 o Windows PowerShell

## Clonazione repository

```powershell
git clone <repo-url>
cd PBI_ProductAnalysis_POC
```

## Dati locali

La repo non versiona:

- `.pbi/`
- `data_source/`
- `xml_oas/`

Quindi, per aprire correttamente i progetti che dipendono da file locali, ogni sviluppatore deve valorizzare la cartella locale `data_source` sul proprio ambiente.

## Progetti disponibili

### Progetto originale

- file: [20260227_Product_Analysis.pbip](../20260227_Product_Analysis.pbip)
- uso: manutenzione del consumer report storico completo

### Semantic core pulito

- file: [20260227_Product_Analysis_Core.pbip](../20260227_Product_Analysis_Core.pbip)
- uso: baseline pulita per nuovi consumer e test di modularizzazione

### Consumer derivato FlexTable

- file: [20260317_Product_Analysis_FlexTable.pbip](../20260317_Product_Analysis_FlexTable.pbip)
- uso: test di moduli installati e consumer derivato con semantic model dedicato

## Parametrizzazione sorgenti locale

Tutti i semantic model del repository adottano ora la stessa convenzione:

- parametro M `root_path`
- valore placeholder in source control: `__SET_LOCAL_DATA_SOURCE_PATH__\`

Prima di usare o refreshare i progetti, valorizza il parametro con il tuo path locale dati.

File interessati:

- `definition/expressions.tmdl` del semantic model

Esempio:

```text
__SET_LOCAL_DATA_SOURCE_PATH__\
```

da sostituire con:

```text
D:\MyLocalData\ProductAnalysis\data_source\
```

Regola di team:

- in Git deve restare solo il placeholder neutro
- i path locali reali non vanno committati

Per configurare rapidamente una copia locale del progetto:

```powershell
./pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command set-data-source-path `
  -ProjectPath ./<progetto>.pbip `
  -DataSourcePath 'C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source'
```

## Moduli

Per vedere i moduli disponibili:

```powershell
./pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command list-modules
```

Per testare la qualita del repo o di un progetto:

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```
