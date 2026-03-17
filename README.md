# Power BI Product Analysis

Repository di lavoro per il progetto `Product Analysis`, oggi in stato di transizione tra:

- consumer project attivo
- semantic core riusabile
- package modulari condivisi
- platform tecnica per installazione e quality checks

## Cosa c'e in root

- [20260227_Product_Analysis.pbip](20260227_Product_Analysis.pbip)
  Progetto consumer originale, con semantic model e report completi.
- [20260227_Product_Analysis_Core.pbip](20260227_Product_Analysis_Core.pbip)
  Baseline pulita del semantic core, da usare come base comune.
- [20260317_Product_Analysis_FlexTable.pbip](20260317_Product_Analysis_FlexTable.pbip)
  Consumer derivato che usa un semantic model dedicato e moduli installati.
- [pbi-modular-platform](pbi-modular-platform)
  Installer, testing framework, schemi metadata e documentazione lifecycle.
- [pbi-finance-domain](pbi-finance-domain)
  Package source del dominio finance.
- [pbi-marketing-domain](pbi-marketing-domain)
  Package source del dominio marketing.

## Quale progetto aprire

- Vuoi lavorare sul report storico completo: apri `20260227_Product_Analysis.pbip`
- Vuoi partire da una base pulita governata: apri `20260227_Product_Analysis_Core.pbip`
- Vuoi testare i moduli `FlexTable`: apri `20260317_Product_Analysis_FlexTable.pbip`

## Contract attuale della repo

Questa repo oggi non e ancora lo split finale in repository distinte.
La sua interpretazione ufficiale e:

- workspace principale di transizione
- contiene asset PBIP attivi ancora usati dal team
- contiene anche il primo scaffolding dei futuri repo `platform` e `domain`

Gli asset oggi considerati autorevoli sono:

- i tre progetti PBIP in root
- i package source dentro `pbi-finance-domain` e `pbi-marketing-domain`
- l'infrastruttura tecnica in `pbi-modular-platform`

## Documentazione

- [Setup](docs/SETUP.md)
- [Workflow](docs/WORKFLOW.md)
- [Repository Contract](docs/REPOSITORY_CONTRACT.md)
- [Topology Note](REPO_TOPOLOGY.md)

## Stato attuale

La repo e apribile e testabile, ma non e ancora completamente industrializzata.
I gap principali ancora aperti sono:

- audit e pulizia completa del semantic core
- workflow di upgrade esplicito dei moduli
- split fisico finale in repo distinte
