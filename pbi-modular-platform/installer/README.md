# Installer

Planned common commands:
- `list-modules`
- `install-module`
- `upgrade-module`
- `validate-project`

Expected workflow:
1. Read the package catalog from a domain repo.
2. Validate required core measures and columns.
3. Auto-map known canonical inputs.
4. Ask only for missing mappings.
5. Copy semantic assets into the consumer semantic model.
6. Copy page/report assets into the consumer report.
7. Persist installed-module metadata for future upgrades.

Current MVP:
- PowerShell CLI entry point: `installer/Invoke-PbiModuleInstaller.ps1`
- implemented commands:
  - `list-modules`
  - `validate-project`
  - `install-module`
- implemented domain resolver:
  - `finance`

Architecture:
- `Modules/Common`
  logging helpers
- `Modules/Core`
  runtime utilities, catalog, project resolution, semantic model install, report install
- `Modules/Domains`
  domain-specific mapping rules
- `Modules/Services`
  orchestration layer for validation and installation

Usage examples:

```powershell
./pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command list-modules
```

```powershell
./pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command validate-project `
  -ProjectPath ./20260227_Product_Analysis_Core.pbip
```

```powershell
./pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command install-module `
  -ProjectPath ./20260227_Product_Analysis_Core.pbip `
  -ModuleId finance_compare_mvp `
  -Domain finance `
  -ActivateInstalledPage
```

Notes:
- installed-module metadata is stored per PBIP project under `module-config/<pbip-name>/installed-modules.json`
- the current installer validates requirements and records mappings, but it does not yet rewrite TMDL based on custom aliases
