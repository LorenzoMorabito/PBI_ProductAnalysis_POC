# Quality Checks

`testing/Invoke-PbiQualityChecks.ps1` e il primo quality gate per asset Power BI modulari e consumer `PBIP`.

## Comandi implementati

- `list-rules`
- `test-module`
- `test-project`
- `test-repo`
- `smoke-install`

## Architettura

- `Modules/Common`
  result objects e summary helpers
- `Modules/Core`
  discovery helpers per `TMDL`, `PBIR`, `PBIP` e contract architetturali
- `Modules/Rules`
  regole statiche su manifest, semantic model, report e architettura
- `Modules/Services`
  orchestration per module checks, project checks e sandbox smoke install

## Regole coperte oggi

- duplicate measure names
- missing semantic o report asset dichiarati da un modulo
- moduli che dichiarano tabelle riservate al semantic core
- core baseline che deviano dal contract approvato
- JSON report invalidi
- textbox con semantic query non valida
- report che referenziano entita non presenti nel semantic model
- field parameter wiring incompleto
- incoerenze `pages.json` / `page.json`
- path locali assoluti non consentiti nei semantic model

## Esempi d'uso

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command list-rules
```

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-module `
  -Domain marketing `
  -ModuleId flex_table_flat_mvp `
  -FailOnError
```

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./powerbi-projects/20260317_Product_Analysis_FlexTable.pbip `
  -FailOnError
```

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command smoke-install `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -Domain finance `
  -ModuleId finance_compare_mvp `
  -FailOnError
```

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```

## Note operative

- `smoke-install` clona il target in un sandbox temporaneo, reinstalla il modulo e valida il risultato
- il framework e statico/sandbox: non automatizza un ciclo completo di apertura/render di Power BI Desktop
- oggi i 4 progetti `PBIP` versionati passano `test-project`
