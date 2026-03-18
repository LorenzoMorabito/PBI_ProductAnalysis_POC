# Power BI Product Analysis

Repository di lavoro per il progetto `Product Analysis`, organizzata in tre aree principali che rappresentano i tre domini oggi gestiti nello stesso workspace:

- consumer Power BI e semantic model
- modularita, package source e platform tecnica
- repository health monitoring

## Aree principali

- [powerbi-projects](powerbi-projects)
  Contiene i progetti PBIP attivi, i semantic model e `module-config`.
- [modularity](modularity)
  Contiene i package source di dominio e la platform tecnica comune.
- [repository-health](repository-health)
  Contiene il framework di monitoraggio della salute Git della repository.

Restano in root solo gli asset trasversali:

- [.github/workflows](.github/workflows)
- [docs](docs)
- [REPO_TOPOLOGY.md](REPO_TOPOLOGY.md)
- le cartelle locali non versionate `data_source` e `xml_oas`

## Progetti PBIP attivi

- [20260227_Product_Analysis.pbip](powerbi-projects/20260227_Product_Analysis.pbip)
  Progetto consumer originale, con semantic model e report completi.
- [20260227_Product_Analysis_Core.pbip](powerbi-projects/20260227_Product_Analysis_Core.pbip)
  Baseline pulita del semantic core, da usare come base comune.
- [20260317_Product_Analysis_FlexTable.pbip](powerbi-projects/20260317_Product_Analysis_FlexTable.pbip)
  Consumer derivato che usa un semantic model dedicato e moduli installati.

## Quale progetto aprire

- Vuoi lavorare sul report storico completo: apri `powerbi-projects/20260227_Product_Analysis.pbip`
- Vuoi partire da una base pulita governata: apri `powerbi-projects/20260227_Product_Analysis_Core.pbip`
- Vuoi testare i moduli `FlexTable`: apri `powerbi-projects/20260317_Product_Analysis_FlexTable.pbip`

## Contract attuale della repo

Questa repo non e ancora lo split finale in repository distinte. La sua interpretazione ufficiale e:

- workspace principale di transizione
- asset PBIP attivi separati dall'authoring modulare
- framework di monitoring separato ma integrato

Gli asset oggi considerati autorevoli sono:

- i progetti PBIP dentro `powerbi-projects`
- i package source dentro `modularity/pbi-finance-domain` e `modularity/pbi-marketing-domain`
- l'infrastruttura tecnica in `modularity/pbi-modular-platform`
- il framework di monitoring in `repository-health`

## Documentazione

- [Setup](docs/SETUP.md)
- [Workflow](docs/WORKFLOW.md)
- [Repository Contract](docs/REPOSITORY_CONTRACT.md)
- [Core Audit](docs/CORE_AUDIT.md)
- [Core vs Modules](docs/ARCHITECTURE_BOUNDARY.md)
- [Target Repo Structure](docs/TARGET_REPO_STRUCTURE.md)
- [UAT Pilot](docs/UAT_PILOT.md)
- [UAT Feedback Template](docs/UAT_FEEDBACK_TEMPLATE.md)
- [Topology Note](REPO_TOPOLOGY.md)

## Stato attuale

La repo e apribile e testabile. I gap principali ancora aperti sono:

- workflow di upgrade esplicito dei moduli
- eventuale split finale in repo distinte quando il contract sara maturo
