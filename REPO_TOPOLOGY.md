# Repository Topology

This repo is now organized into three main working areas that reflect the three active domains.

Current top-level topology:
- `powerbi-projects`
  Active PBIP consumer projects, semantic models, and `module-config`.
- `modularity`
  Shared installer, schemas, lifecycle docs, validation rules, and domain package sources.
- `repository-health`
  Git repository health monitoring framework and persistent telemetry configuration.

Current migration status:
- The source package `finance_compare_mvp` lives in `modularity/pbi-finance-domain/packages/finance_compare_mvp`.
- Installed assets remain inside the active consumer project:
  - `powerbi-projects/20260227_Product_Analysis_Core.SemanticModel`
  - `powerbi-projects/20260227_Product_Analysis_Core.Report`
- The original, core, derived, and UAT PBIP projects now live together under `powerbi-projects`.

Working rule:
- `package source` lives in the domain area.
- `installed package assets` stay in the consumer project area.
- Upgrades must be explicit and versioned.

Next migration steps:
- keep the shared installer authoritative in `modularity/pbi-modular-platform`
- keep domain package authoring under `modularity/*-domain`
- split to independent repositories only when branch, release, and upgrade contracts are stable
