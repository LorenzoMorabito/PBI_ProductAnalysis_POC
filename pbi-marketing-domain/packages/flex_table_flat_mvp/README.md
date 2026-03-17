# FlexTableFlat MVP

Flat-table companion module for the existing pivot-style flex table.

Contents:
- wrapper measures around the curated core sales, promo, and finance measures
- one flat column selector parameter that mixes dimensions and measures
- one standard `tableEx` visual that renders the selected columns as normal table columns

Current selectable columns:
- dimensions:
  - `Country`
  - `Corporation`
  - `Product`
  - `Molecule`
  - `Quarter`
  - `ATC4`
- measures:
  - `Sales Values`
  - `Sales Units`
  - `Counting Units`
  - `Promo Spend`
  - `Promo Details`
  - `Promo Contacts`
  - `Promo Weighted Calls`
  - `Fin ACT`
  - `Fin BDG`
  - `Fin ACT PY`

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
- this module is intentionally flat: selected dimensions are rendered as normal columns, not row groups
- the current interaction pattern uses a single multi-select slicer for all output columns
