# Installer

`installer/Invoke-PbiModuleInstaller.ps1` e l'entry point PowerShell per l'installazione dei package nei consumer `PBIP`.

## Comandi supportati

- `list-modules`
- `validate-project`
- `install-module`
- `set-data-source-path`

Comando previsto ma non ancora implementato end-to-end:

- `upgrade-module`

## Workflow implementato

1. Legge i cataloghi di dominio.
2. Valida prerequisiti del modulo contro il consumer target.
3. Risolve i mapping richiesti.
4. Copia gli asset semantici nel semantic model consumer.
5. Copia gli asset report nella pagina consumer.
6. Persiste `installed-modules.json` per i consumer gestiti.

## Architettura

- `Modules/Common`
  logging helpers
- `Modules/Core`
  runtime utilities, catalog discovery, project resolution, semantic/report install
- `Modules/Domains`
  regole di mapping domain-specific
- `Modules/Services`
  orchestration layer per validation e installazione

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
  -Command set-data-source-path `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -DataSourcePath 'C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source'
```

## Note operative

- i metadata installativi sono salvati sotto `powerbi-projects/module-config/<pbip-name>/installed-modules.json`
- l'installer oggi lavora bene per installazioni nuove e setup locale del path dati
- il lifecycle di upgrade esplicito resta il prossimo hardening
