# Quality Checks

`testing/Invoke-PbiQualityChecks.ps1` is the first quality gate for modular Power BI assets.

Implemented commands:
- `list-rules`
- `test-module`
- `test-project`
- `test-repo`
- `smoke-install`

Architecture:
- `Modules/Common`
  result objects and summary helpers
- `Modules/Core`
  discovery helpers for TMDL, report assets and PBIP projects
- `Modules/Rules`
  static quality rules split by manifest, semantic model and report assets
- `Modules/Services`
  orchestration for module checks, project checks and sandbox smoke install

Current rules focus on the failures we have already seen in real work:
- duplicate measure names
- missing semantic or report assets declared by a module
- modules that attempt to declare tables reserved for the semantic core
- core baseline projects that drift away from the approved semantic core contract
- invalid JSON in report assets
- textbox visuals that incorrectly carry semantic queries
- stale module report references to removed `MOD_*` tables
- direct field-parameter projections without `fieldParameters` metadata
- report visuals referencing entities not present in the semantic model
- broken `pages.json` / `page.json` consistency

Usage examples:

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command list-rules
```

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-module `
  -Domain marketing `
  -ModuleId flex_table_flat_mvp `
  -FailOnError
```

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./20260317_Product_Analysis_FlexTable.pbip `
  -FailOnError
```

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command smoke-install `
  -ProjectPath ./20260227_Product_Analysis_Core.pbip `
  -Domain finance `
  -ModuleId finance_compare_mvp `
  -FailOnError
```

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```

Notes:
- `smoke-install` clones the target project into a temp sandbox, removes any existing installation of the selected module, reinstalls it with the installer service, and runs project checks on the sandbox result.
- this is a static/sandbox framework; it does not automate a full Power BI Desktop open/render cycle
