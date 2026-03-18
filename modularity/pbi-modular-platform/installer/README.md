# Installer

`installer/Invoke-PbiModuleInstaller.ps1` e l'entry point PowerShell per l'installazione dei package nei consumer `PBIP`.

## Comandi supportati

- `list-modules`
- `validate-project`
- `install-module`
- `upgrade-module`
- `diff-module`
- `rollback-module`
- `set-data-source-path`

## Workflow implementato

1. Legge i cataloghi di dominio.
2. Valida prerequisiti del modulo contro il consumer target.
3. Risolve i mapping richiesti.
4. Crea snapshot pre-write dei file impattati.
5. Copia gli asset semantici nel semantic model consumer.
6. Copia gli asset report nella pagina consumer.
7. Persiste `installed-modules.json` per i consumer gestiti.
8. Registra log strutturato, diff e metriche di governance.

## Architettura

- `Modules/Common`
  logging helpers console + JSON
- `Modules/Core`
  runtime utilities, schema validation, catalog discovery, project resolution, semantic/report install
- `Modules/Domains`
  regole di mapping domain-specific
- `Modules/Services`
  orchestration layer per validation, lifecycle, governance e repo-health

## Esempi d'uso

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command list-modules
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command validate-project `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command install-module `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -ModuleId finance_compare_mvp `
  -Domain finance `
  -ActivateInstalledPage
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command upgrade-module `
  -ProjectPath ./powerbi-projects/20260317_UAT_001.pbip `
  -ModuleId finance_compare_mvp `
  -Domain finance
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command diff-module `
  -ProjectPath ./powerbi-projects/20260317_UAT_001.pbip `
  -ModuleId finance_compare_mvp `
  -Domain finance
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command rollback-module `
  -ProjectPath ./powerbi-projects/20260317_UAT_001.pbip `
  -ModuleId finance_compare_mvp
```

```powershell
./modularity/pbi-modular-platform/installer/Invoke-PbiModuleInstaller.ps1 `
  -Command set-data-source-path `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -DataSourcePath 'C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source'
```

## Note operative

- i metadata installativi sono salvati sotto `powerbi-projects/module-config/<pbip-name>/installed-modules.json`
- snapshot, diff e log sono salvati sotto `powerbi-projects/module-config/<pbip-name>/`
- la governance usa `config/modularity-governance.json` e puo integrare `repository-health`
- il gate `repository-health` valuta regressioni rispetto al baseline pre-operazione, non debito storico gia presente nel repo
- i comandi funzionano sia con `pwsh` sia con `powershell`
