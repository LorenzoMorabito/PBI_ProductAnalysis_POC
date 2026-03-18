# Power BI Product Analysis

Repository di lavoro per `Product Analysis`, oggi organizzata in tre aree ufficiali che rappresentano i tre domini operativi gestiti nello stesso workspace Git.

## Aree ufficiali

- [powerbi-projects](powerbi-projects)
  Progetti `PBIP`, semantic model, report attivi e `module-config`.
- [modularity](modularity)
  Package source di dominio, installer, quality checks, lifecycle e schemi.
- [repository-health](repository-health)
  Framework di monitoraggio Git con persistenza storica su branch dedicato.

In root restano solo gli asset trasversali:

- [.github/workflows](.github/workflows)
- [docs](docs)
- [REPO_TOPOLOGY.md](REPO_TOPOLOGY.md)
- i folder locali non versionati `data_source` e `xml_oas`

## Progetti Power BI attivi

| Progetto | Ruolo | Stato attuale |
| --- | --- | --- |
| [20260227_Product_Analysis.pbip](powerbi-projects/20260227_Product_Analysis.pbip) | consumer storico completo | semantic model esteso con logiche consumer-specific |
| [20260227_Product_Analysis_Core.pbip](powerbi-projects/20260227_Product_Analysis_Core.pbip) | baseline pulita | semantic core governato, senza `MOD_*` |
| [20260317_Product_Analysis_FlexTable.pbip](powerbi-projects/20260317_Product_Analysis_FlexTable.pbip) | consumer derivato | semantic model dedicato con `FlexTablePivot` e `FlexTableFlat` |
| [20260317_UAT_001.pbip](powerbi-projects/20260317_UAT_001.pbip) | progetto UAT | installazione progressiva validata di 3 moduli |

## Moduli disponibili

| Dominio | Modulo | Versione | Stato |
| --- | --- | --- | --- |
| finance | `finance_compare_mvp` | `0.1.0` | `prototype` |
| marketing | `flex_metrics_table_mvp` | `0.2.1` | `prototype` |
| marketing | `flex_table_flat_mvp` | `0.2.0` | `prototype` |

## Quale progetto aprire

- Per lavorare sul report storico completo: `powerbi-projects/20260227_Product_Analysis.pbip`
- Per partire da una baseline governata: `powerbi-projects/20260227_Product_Analysis_Core.pbip`
- Per testare il consumer derivato dei moduli FlexTable: `powerbi-projects/20260317_Product_Analysis_FlexTable.pbip`
- Per ripetere il flusso UAT su un caso gia validato: `powerbi-projects/20260317_UAT_001.pbip`

## Contract attuale della repo

Questa repo non e ancora lo split finale in repository distinte. La sua interpretazione ufficiale e:

- workspace di transizione governato
- separazione fisica tra consumer PBIP, authoring modulare e monitoring Git
- stesso contesto di lavoro, ma domini documentati e testabili in modo indipendente

Gli asset autorevoli oggi sono:

- i progetti `PBIP` sotto `powerbi-projects`
- i package source sotto `modularity/pbi-finance-domain` e `modularity/pbi-marketing-domain`
- la platform tecnica sotto `modularity/pbi-modular-platform`
- il framework di monitoring sotto `repository-health`
- il branch `repo-health-data` come storage storico della telemetria Git

## Stato attuale

Lo stato corrente validato del workspace e documentato in [Project Status](docs/PROJECT_STATUS.md).

In sintesi:

- i 4 progetti `PBIP` versionati passano `test-project`
- `test-repo -FailOnError` passa
- il framework `repository-health` e attivo e funzionante
- resta aperto il tema del lifecycle `upgrade-module`, non ancora implementato end-to-end

## Documentazione

- [Project Status](docs/PROJECT_STATUS.md)
- [Setup](docs/SETUP.md)
- [Workflow](docs/WORKFLOW.md)
- [Repository Contract](docs/REPOSITORY_CONTRACT.md)
- [Core Audit](docs/CORE_AUDIT.md)
- [Core vs Modules](docs/ARCHITECTURE_BOUNDARY.md)
- [Target Repo Structure](docs/TARGET_REPO_STRUCTURE.md)
- [UAT Pilot](docs/UAT_PILOT.md)
- [UAT Feedback Template](docs/UAT_FEEDBACK_TEMPLATE.md)
- [Topology Note](REPO_TOPOLOGY.md)
