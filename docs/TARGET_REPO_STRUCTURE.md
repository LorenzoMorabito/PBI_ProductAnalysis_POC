# Target Repo Structure

Data decisione: `2026-03-18`

## Principio

La repo e stata separata fisicamente in tre aree principali senza spezzare ancora il workspace in repository distinte.

La strategia resta in due tempi:

- `Fase 1`: separazione fisica locale e chiarezza di dominio dentro la repo attuale
- `Fase 2`: split in repo distinte quando installer, package lifecycle e consumer contract saranno stabili

## Struttura operativa attuale

### 1. Power BI projects

Asset `PBIP` usati dal team:

- `powerbi-projects/20260227_Product_Analysis.*`
- `powerbi-projects/20260227_Product_Analysis_Core.*`
- `powerbi-projects/20260317_Product_Analysis_FlexTable.*`
- `powerbi-projects/20260317_UAT_001.*`
- `powerbi-projects/module-config/*`

Ruoli:

- `Product_Analysis`: consumer storico completo
- `Product_Analysis_Core`: baseline pulita
- `Product_Analysis_FlexTable`: consumer derivato con semantic model dedicato
- `UAT_001`: consumer di test per validare il flusso modulare

### 2. Modularity

- `modularity/pbi-finance-domain`
- `modularity/pbi-marketing-domain`
- `modularity/pbi-modular-platform`

Ruolo:

- ospitare i package source di dominio
- ospitare installer, quality checks, schemi metadata e lifecycle docs
- tenere separato l'authoring modulare dai consumer PBIP

### 3. Repository health

- `repository-health`
- branch dati `repo-health-data`

Ruolo:

- monitoraggio della salute Git della repository
- configurazione threshold e persistenza storica
- supporto ai workflow GitHub Actions dedicati
- storage storico diffabile su branch separato

## Split finale raccomandato

### Repo 1: consumer workspace

Contiene:

- consumer attivi
- semantic model derivati installati
- `module-config`

Non contiene:

- sorgenti package come punto di authoring principale
- piattaforma tecnica comune

### Repo 2: modular platform

Contiene:

- installer
- validation framework
- schemi JSON
- CI support
- lifecycle docs

### Repo 3: finance domain

Contiene:

- package finance
- eventuali finance consumer futuri

### Repo 4: marketing domain

Contiene:

- package marketing
- eventuali marketing consumer futuri

### Repo 5: repository health

Contiene:

- framework repo-health
- workflow CI dedicati
- eventuale telemetria storica o configurazione del branch dati

## Struttura ufficiale corrente

```text
/
  powerbi-projects/
    20260227_Product_Analysis*
    20260227_Product_Analysis_Core*
    20260317_Product_Analysis_FlexTable*
    20260317_UAT_001*
    module-config/
  modularity/
    pbi-finance-domain/
    pbi-marketing-domain/
    pbi-modular-platform/
  repository-health/
  .github/
  docs/
```

## Cosa non fare ora

- non creare una repo per ogni singolo package
- non introdurre riferimenti live tra repo che propagano modifiche in automatico ai consumer
- non spostare arbitrariamente i consumer fuori da `powerbi-projects` senza un passo di migrazione esplicito

## Trigger per lo split fisico

Lo split in repo distinte va eseguito solo quando sono vere tutte queste condizioni:

- installer stabile con `install` e `upgrade`
- metadata moduli affidabili
- contract `core vs module` approvato
- almeno un consumer derivato gestito con successo
- team allineato sul workflow Git e PBIP

## Verdetto

La separazione in tre aree e corretta e rappresenta il layout ufficiale corrente.

Lo stato operativo aggiornato del workspace e documentato in [Project Status](PROJECT_STATUS.md).
