# Semantic Core Audit

Data audit: `2026-03-17`

Perimetro analizzato:

- [20260227_Product_Analysis_Core.pbip](../20260227_Product_Analysis_Core.pbip)
- [20260227_Product_Analysis_Core.SemanticModel](../20260227_Product_Analysis_Core.SemanticModel)

## Sintesi

Stato attuale del core:

- `15` tabelle
- `15` relazioni
- `10` relazioni `AutoDetected`
- `1` relazione bidirezionale

Verdetto:

- il `Core` e ora pulito dal punto di vista dei moduli `MOD_*`
- non risultano helper report-specifici residui
- gli artefatti `Auto Date/Time` sono stati rimossi dal core
- alcune relazioni vanno industrializzate, soprattutto quelle `AutoDetected`

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

### Da riesplicitare

Le `10` relazioni `AutoDetected` non sono sbagliate per forza, ma non sono ancora abbastanza governate per un core industrializzato.

Target successivo:

- renderle esplicite e intenzionali
- verificare cardinalita e chiavi
- evitare dipendenza implicita da comportamento Desktop

### Da rivedere

Relazione bidirezionale in [relationships.tmdl](../20260227_Product_Analysis_Core.SemanticModel/definition/relationships.tmdl):

- `T_DIM_MOLECULE[MoleculeNorm] -> T_DIM_PRODUCT[MoleculeNorm]`
- `crossFilteringBehavior: bothDirections`

Verdetto:

- `REVIEW`
- puo essere corretta per il modello attuale, ma e un punto ad alto rischio per ambiguita di filtro e performance

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

1. Riesplicitare le relazioni `AutoDetected`
2. Rivalutare la relazione bidirezionale `Molecule -> Product`
3. Verificare se `T_DIM_SPECIALTY` e `T_DIM_CHANNELS` devono restare nel core oppure diventare domain-core promo
