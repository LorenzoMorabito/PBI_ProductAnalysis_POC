# Flex Metrics Table MVP

Versione corrente: `0.2.1`

First marketing-domain table module built as an importable package.

Contents:
- wrapper measures around a curated set of core sales, promo, and finance measures
- a disconnected metric selector with multi-select column behavior
- a disconnected shared axis table used to switch the row dimension
- a visual pack with:
  - multi-select dimension slicer
  - multi-select metric slicer
  - pivot-style flexible table visual

Scope of the MVP:
- multi-select row dimensions with a hierarchical row layout
- current row dimensions:
  - `Molecule`
  - `Country`
  - `Corporation`
  - `Product`
  - `Quarter`
  - `ATC4`
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
  - `T_DIM_CORPORATION[Corporation]`
  - `T_DIM_PRODUCT[Product]`
  - `T_DIM_QUARTER[QuarterKey]`
  - `T_DIM_ACT4[ATC4]`

Notes:
- this MVP now supports multi-select row dimensions by grouping the table as `Dimension -> Value`
- the package source lives here; installed copies remain managed artifacts in consumer projects

Current validated consumers:
- `powerbi-projects/20260317_Product_Analysis_FlexTable.pbip`
- `powerbi-projects/20260317_UAT_001.pbip`
