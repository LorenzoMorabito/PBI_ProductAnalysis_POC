# Flex Metrics Table MVP

First marketing-domain table module built as an importable package.

Contents:
- wrapper measures around a curated set of core sales, promo, and finance measures
- a disconnected metric selector with multi-select column behavior
- a disconnected shared axis table used to switch the row dimension
- a table visual pack with:
  - single-select dimension slicer
  - multi-select metric slicer
  - flexible table visual

Scope of the MVP:
- shared dimensions only, to avoid semantically misleading combinations
- current safe row dimensions:
  - `Molecule`
  - `Country`
  - `Quarter`
- current measure set is intentionally numeric and absolute only

Required core contract:
- measures:
  - `[Sales Values]`
  - `[Sales Units]`
  - `[Counting Units]`
  - `[Promo Spend]`
  - `[Promo Details]`
  - `[Promo Contacts]`
  - `[Promo Weighted Calls]`
  - `[Fin ACT]`
  - `[Fin BDG]`
  - `[Fin ACT PY]`
- columns:
  - `T_DIM_MOLECULE[MoleculeNorm]`
  - `T_DIM_COUNTRY[Country]`
  - `T_DIM_QUARTER[QuarterKey]`

Notes:
- this MVP avoids product-, corporation-, channel-, and specialty-level rows because those dimensions are not safe across all three domains in the current core model
- the package source lives here; installed copies remain managed artifacts in consumer projects
