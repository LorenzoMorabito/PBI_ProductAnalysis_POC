# Finance Compare MVP

First importable finance package prototype.

Contents:
- a semantic adapter layer with wrappers around finance core measures
- a disconnected selector for `vs BDG` / `vs PY`
- derived measures for absolute and percentage delta
- a minimal PBIR page with slicer and KPI visuals

Required core contract:
- `[Fin ACT]`
- `[Fin BDG]`
- `[Fin ACT PY]`
- `[T_DIM_MONTH].[MonthStartDay]`

Packaging strategy:
- the module uses only `Input ...` wrapper measures
- the report pack points only to module-owned objects
- the current MVP mapping is fixed to the existing core model contract

Repository role:
- this folder is the package source of truth for the finance domain
- installed copies inside consumer projects are managed artifacts and remain versioned with the consumer repo
