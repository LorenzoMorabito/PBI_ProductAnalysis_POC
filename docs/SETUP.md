# Setup

## Prerequisiti

- Power BI Desktop con supporto `PBIP`, `TMDL` ed `Enhanced report format`
- Git
- PowerShell 7 oppure Windows PowerShell

## Clonazione repository

```powershell
git clone <repo-url>
cd PBI_ProductAnalysis_POC
```

## Layout della repository

Dopo la clonazione la struttura operativa e:

- `powerbi-projects`
- `modularity`
- `repository-health`

I progetti `PBIP` da aprire in Power BI Desktop vivono sempre sotto `powerbi-projects`.

## Dati locali

La repo non versiona:

- `.pbi/`
- `data_source/`
- `xml_oas/`

Per aprire correttamente i progetti che dipendono da file locali serve quindi una cartella dati locale valida.

## Progetti disponibili

### Progetto originale

- file: [20260227_Product_Analysis.pbip](../powerbi-projects/20260227_Product_Analysis.pbip)
- uso: manutenzione del consumer storico completo

### Semantic core pulito

- file: [20260227_Product_Analysis_Core.pbip](../powerbi-projects/20260227_Product_Analysis_Core.pbip)
- uso: baseline pulita per nuovi consumer e test di modularizzazione

### Consumer derivato FlexTable

- file: [20260317_Product_Analysis_FlexTable.pbip](../powerbi-projects/20260317_Product_Analysis_FlexTable.pbip)
- uso: esempio di consumer derivato con semantic model dedicato e moduli installati

### Progetto UAT

- file: [20260317_UAT_001.pbip](../powerbi-projects/20260317_UAT_001.pbip)
- uso: riferimento del primo giro UAT completato

## Parametrizzazione sorgenti locali

Tutti i semantic model versionati usano il parametro M `root_path`.

Valore versionato oggi:

```text
C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\
```

Se lavori su un ambiente diverso, prima di usare o refreshare i progetti aggiorna `root_path` sulla tua copia locale.

File interessati:

- `definition/expressions.tmdl` del semantic model

Esempio di override locale:

```text
D:\MyLocalData\ProductAnalysis\data_source\
```

Regole di team:

- il path versionato e il default operativo del workspace corrente
- se serve un path diverso, l'override va fatto sulla copia locale di lavoro
- evitare di introdurre nuovi path ambientali senza accordo esplicito

Per aggiornare rapidamente un progetto locale:

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

Per testare un progetto:

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -FailOnError
```

Per testare l'intera repository:

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```
