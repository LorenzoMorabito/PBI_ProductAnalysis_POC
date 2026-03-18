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

- file: [20260227_Product_Analysis.pbip](../powerbi-projects/20260227_Product_Analysis.pbip)
- uso: manutenzione del consumer report storico completo

### Semantic core pulito

- file: [20260227_Product_Analysis_Core.pbip](../powerbi-projects/20260227_Product_Analysis_Core.pbip)
- uso: baseline pulita per nuovi consumer e test di modularizzazione

### Consumer derivato FlexTable

- file: [20260317_Product_Analysis_FlexTable.pbip](../powerbi-projects/20260317_Product_Analysis_FlexTable.pbip)
- uso: test di moduli installati e consumer derivato con semantic model dedicato

## Parametrizzazione sorgenti locale

Tutti i semantic model del repository adottano ora la stessa convenzione:

- parametro M `root_path`
- valore standard attualmente versionato: `C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\`

Se lavori su un ambiente diverso, prima di usare o refreshare i progetti aggiorna il parametro con il tuo path locale dati.

File interessati:

- `definition/expressions.tmdl` del semantic model

Esempio di override locale:

```text
D:\MyLocalData\ProductAnalysis\data_source\
```

Regola di team:

- il path versionato va trattato come default operativo del workspace corrente
- se viene usato un path diverso, l'override va fatto sulla copia locale di lavoro
- evitare di introdurre nuovi path ambientali senza accordo esplicito

Per configurare rapidamente una copia locale del progetto:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command set-data-source-path `
  -ProjectPath ./powerbi-projects/<progetto>.pbip `
  -DataSourcePath 'C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source'
```

## Moduli

Per vedere i moduli disponibili:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command list-modules
```

Per testare la qualita del repo o di un progetto:

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```
