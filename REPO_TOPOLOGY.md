# Repository Topology

This repo now contains the first scaffolding for a future split into separate repositories.

Target topology:
- `pbi-modular-platform`
  Common installer, schemas, lifecycle docs, and validation rules.
- `pbi-finance-domain`
  Finance package sources and future finance projects.
- `pbi-marketing-domain`
  Future home for marketing core models and marketing consumer projects.

Current migration status:
- The source package `finance_compare_mvp` has been moved to `pbi-finance-domain/packages/finance_compare_mvp`.
- The installed assets remain inside the active consumer project:
  - `20260227_Product_Analysis_Core.SemanticModel`
  - `20260227_Product_Analysis_Core.Report`
- The original and core PBIP projects stay at repo root for now to avoid breaking the current workflow.

Working rule:
- `package source` lives in the domain repo.
- `installed package assets` stay in the consumer project repo.
- Upgrades must be explicit and versioned.

Next migration steps:
- build the shared installer in `pbi-modular-platform`
- add installed-module metadata to consumer projects
- move the marketing project into `pbi-marketing-domain/projects/product-analysis-poc` only when the team is ready
