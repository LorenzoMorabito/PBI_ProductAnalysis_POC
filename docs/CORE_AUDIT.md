# Semantic Core Audit

Data audit: `2026-03-17`

Perimetro analizzato:

- [20260227_Product_Analysis_Core.pbip](../20260227_Product_Analysis_Core.pbip)
- [20260227_Product_Analysis_Core.SemanticModel](../20260227_Product_Analysis_Core.SemanticModel)

## Sintesi

Stato attuale del core:

- `15` tabelle
- `15` relazioni
- `0` relazioni `AutoDetected`
- `0` relazioni bidirezionali

Verdetto:

- il `Core` e ora pulito dal punto di vista dei moduli `MOD_*`
- non risultano helper report-specifici residui
- gli artefatti `Auto Date/Time` sono stati rimossi dal core
- le relazioni del core sono ora esplicite e con naming intenzionale

## Classificazione oggetti

| Oggetto | Gruppo | Verdetto | Nota |
| --- | --- | --- | --- |
| `T_FCT_SALES_A10P` | business core | `KEEP` | fact sales principale |
| `T_FCT_PROMO_A10P_CD` | business core | `KEEP` | fact promo principale |
| `T_FCT_FIN` | business core | `KEEP` | fact finance principale |
| `T_DIM_COUNTRY` | business core | `KEEP` | dimensione condivisa |
| `T_DIM_MOLECULE` | business core | `KEEP` | dimensione condivisa |
| `T_DIM_ACT4` | business core | `KEEP` | dimensione condivisa |
| `T_DIM_PRODUCT` | business core | `KEEP` | dimensione cardine del dominio |
| `T_DIM_MONTH` | business core | `KEEP` | dimensione tempo usata dal finance |
| `T_DIM_QUARTER` | business core | `KEEP` | dimensione tempo usata cross-domain |
| `T_DIM_CORPORATION` | business core | `KEEP` | dimensione condivisa |
| `T_DIM_SPECIALTY` | business core | `KEEP` | dimensione dominio promo |
| `T_DIM_CHANNELS` | business core | `KEEP` | dimensione dominio promo |
| `Msr Sales` | business core | `KEEP` | measure table core sales |
| `Msr Promo` | business core | `KEEP` | measure table core promo |
| `Msr Fin` | business core | `KEEP` | measure table core finance |
## Oggetti non tabellari

| Oggetto | Gruppo | Verdetto | Nota |
| --- | --- | --- | --- |
| `root_path` | supporto tecnico riusabile | `KEEP` | parametro neutro per data source locale |
| `en-US` culture | supporto tecnico riusabile | `KEEP` | standard model metadata |

## Relazioni da attenzionare

### Stato attuale

Le relazioni residue del core hanno ora naming esplicito, per esempio:

- `REL_FIN_COUNTRY`
- `REL_PROMO_PRODUCT`
- `REL_MONTH_QUARTER`
- `REL_MOLECULE_PRODUCT`

La relazione tra [T_DIM_MOLECULE](../20260227_Product_Analysis_Core.SemanticModel/definition/tables/T_DIM_MOLECULE.tmdl) e [T_DIM_PRODUCT](../20260227_Product_Analysis_Core.SemanticModel/definition/tables/T_DIM_PRODUCT.tmdl) e stata riportata a filtro monodirezionale.

Verdetto:

- miglioramento architetturale approvato
- minore rischio di ambiguita di filtro
- resta comunque da verificare nel tempo se `T_DIM_MOLECULE` debba restare snowflake su `T_DIM_PRODUCT` oppure diventare una dimensione ancora piu esplicita

## Misure core

Stato corrente:

- `Msr Sales`: misure base e time intelligence semplice
- `Msr Promo`: misure base, market share e confronto PY
- `Msr Fin`: misure base finance e confronto `ACT/BDG/PY`

Verdetto:

- coerenti con il ruolo di core
- non emergono dipendenze residue da moduli `TopN`, `Buckets` o `UX`

## Conclusione aggiornata

Classificazione approvabile per il prossimo sprint:

- `business core`: facts, dims, measure tables core
- `supporto tecnico riusabile`: `root_path`, culture
- `residui tecnici Desktop`: rimossi dal core

## Backlog successivo

1. Verificare cardinalita e chiavi delle relazioni ora esplicitate
2. Validare funzionalmente i report piu sensibili sul filtro `Molecule -> Product`
3. Verificare se `T_DIM_SPECIALTY` e `T_DIM_CHANNELS` devono restare nel core oppure diventare domain-core promo
