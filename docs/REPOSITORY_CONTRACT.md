# Repository Contract

## Interpretazione ufficiale della repo

Questa repo e oggi una `transition workspace repo`, ma con una separazione fisica esplicita in tre aree:

- `powerbi-projects`
- `modularity`
- `repository-health`

Non e ancora il risultato finale dello split in repository distinte, ma e il layout operativo ufficiale corrente.

## Asset autorevoli

### Consumer attivi

- [20260227_Product_Analysis.pbip](../powerbi-projects/20260227_Product_Analysis.pbip)
- [20260227_Product_Analysis_Core.pbip](../powerbi-projects/20260227_Product_Analysis_Core.pbip)
- [20260317_Product_Analysis_FlexTable.pbip](../powerbi-projects/20260317_Product_Analysis_FlexTable.pbip)

### Package source

- [modularity/pbi-finance-domain](../modularity/pbi-finance-domain)
- [modularity/pbi-marketing-domain](../modularity/pbi-marketing-domain)

### Platform tecnica

- [modularity/pbi-modular-platform](../modularity/pbi-modular-platform)

### Repository health

- [repository-health](../repository-health)

## Regole architetturali

- il progetto originale resta il riferimento del consumer storico
- il `Core` e la baseline pulita riusabile
- i consumer derivati con moduli installati devono avere un semantic model dedicato
- i package source non si sviluppano dentro i semantic model consumer
- il monitoring della repo resta isolato dal codice applicativo ma vive nello stesso workspace
- lo split fisico in repo distinte resta obiettivo futuro, non precondizione per lavorare bene adesso

## Aree ufficiali della repo

- `powerbi-projects`
- `modularity/pbi-finance-domain`
- `modularity/pbi-marketing-domain`
- `modularity/pbi-modular-platform`
- `repository-health`
- [REPO_TOPOLOGY.md](../REPO_TOPOLOGY.md)

Questi elementi rappresentano il layout ufficiale corrente e vanno mantenuti coerenti con gli asset attivi.
