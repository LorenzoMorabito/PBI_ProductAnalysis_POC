# UAT Pilot

## Obiettivo

Validare con utenti business e sviluppatori Power BI non-core che il flusso seguente sia comprensibile e sostenibile:

- partire da una baseline pulita
- installare uno o piu moduli
- aprire il progetto in Power BI Desktop
- verificare che report e semantic model restino coerenti

## Perimetro del pilot

Il pilot UAT attuale e volutamente controllato.

Progetti di partenza consentiti:

- [20260227_Product_Analysis_Core.pbip](../powerbi-projects/20260227_Product_Analysis_Core.pbip)

Moduli consentiti:

- `finance_compare_mvp`
- `flex_metrics_table_mvp`
- `flex_table_flat_mvp`

Asset di riferimento:

- [README.md](../README.md)
- [SETUP.md](SETUP.md)
- [WORKFLOW.md](WORKFLOW.md)

## Profilo utenti

Utenti consigliati per il primo giro:

- `1` owner tecnico del progetto
- `2-4` colleghi Power BI non maintainer
- opzionale `1` reviewer funzionale business

## Prerequisiti

- Power BI Desktop con supporto PBIP/TMDL attivo
- clone aggiornato della repo
- accesso al path locale dati documentato in [SETUP.md](SETUP.md)
- PowerShell disponibile per eseguire installer e quality checks

## Flusso UAT standard

### 1. Preparare un progetto test isolato

Creare una copia locale del `Core` con un nome dedicato al tester, per esempio:

- `20260317_Product_Analysis_Core_UAT_LM.pbip`
- `20260317_Product_Analysis_Core_UAT_LM.Report`
- `20260317_Product_Analysis_Core_UAT_LM.SemanticModel`

Regola:

- ogni tester lavora su una propria copia
- il `Core` ufficiale non va modificato durante l'UAT

### 2. Configurare il path dati locale

Prima di aprire il progetto in Desktop, valorizzare `root_path` sulla copia UAT:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command set-data-source-path `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -DataSourcePath 'C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source'
```

### 3. Aprire il progetto test

Aprire il nuovo `.pbip` in Power BI Desktop e verificare:

- il progetto si apre
- il model carica
- il report contiene solo la baseline prevista
- non ci sono errori visual

### 4. Validare il progetto prima dell'installazione

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -FailOnError
```

### 5. Installare un solo modulo per volta

Esempio `finance_compare_mvp`:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command install-module `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -Domain finance `
  -ModuleId finance_compare_mvp `
  -ActivateInstalledPage
```

Esempio `flex_metrics_table_mvp`:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command install-module `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -Domain marketing `
  -ModuleId flex_metrics_table_mvp `
  -ActivateInstalledPage
```

Esempio `flex_table_flat_mvp`:

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command install-module `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -Domain marketing `
  -ModuleId flex_table_flat_mvp `
  -ActivateInstalledPage
```

### 6. Rieseguire i quality checks

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./powerbi-projects/<progetto-test>.pbip `
  -FailOnError
```

### 7. Aprire il progetto in Desktop e fare verifica funzionale

Per ogni modulo installato verificare:

- pagina nuova presente
- visual caricati senza errori
- slicer funzionanti
- misure coerenti
- nessuna rottura nelle pagine gia presenti

### 8. Salvare il feedback

Ogni tester compila il template in [UAT_FEEDBACK_TEMPLATE.md](UAT_FEEDBACK_TEMPLATE.md).

## Scenari minimi da eseguire

### Scenario A - Finance Compare

Verificare:

- installazione riuscita
- pagina `Finance Compare MVP` presente
- slicer `vs BDG / vs PY` funzionante
- KPI aggiornati in modo coerente al cambio selezione

### Scenario B - FlexTablePivot

Verificare:

- installazione riuscita
- pagina `FlexTablePivot` presente
- multiselect misure funzionante
- multiselect dimensioni funzionante
- il pivot rende righe per dimensione e colonne per misura

### Scenario C - FlexTableFlat

Verificare:

- installazione riuscita
- pagina `FlexTableFlat` presente
- selezione dimensioni e misure tramite slicer
- tabella standard con colonne descrittive prima e numeriche dopo
- nessun errore di relazioni o proiezioni parameter

## Criteri di accettazione del pilot

Il pilot puo considerarsi superato se:

- almeno `3` utenti completano il flusso
- tutti riescono a installare almeno `1` modulo senza supporto tecnico diretto sul codice
- non emergono errori bloccanti del framework
- il feedback segnala problemi di UX gestibili senza riprogettare l'architettura

## Criteri di stop

Fermare il pilot e aprire fix tecnici se emerge uno di questi casi:

- il progetto test non si apre in Desktop
- l'installer porta il `Core` ufficiale fuori baseline
- i quality checks non intercettano errori evidenti del package
- un modulo installato rompe il report o il semantic model in modo non spiegabile
