# Repository Contract

## Interpretazione ufficiale della repo

Questa repo e oggi una `transition workspace repo`.
Non e ancora il risultato finale dello split architetturale.

Contiene insieme:

- progetti PBIP attivi usati dal team
- semantic core
- consumer derivati
- package source di dominio
- platform tecnica comune

## Asset autorevoli

### Consumer attivi

- [20260227_Product_Analysis.pbip](../20260227_Product_Analysis.pbip)
- [20260227_Product_Analysis_Core.pbip](../20260227_Product_Analysis_Core.pbip)
- [20260317_Product_Analysis_FlexTable.pbip](../20260317_Product_Analysis_FlexTable.pbip)

### Package source

- [pbi-finance-domain](../pbi-finance-domain)
- [pbi-marketing-domain](../pbi-marketing-domain)

### Platform tecnica

- [pbi-modular-platform](../pbi-modular-platform)

## Regole architetturali

- il progetto originale resta il riferimento del consumer storico
- il `Core` e la baseline pulita riusabile
- i consumer derivati con moduli installati devono avere un semantic model dedicato
- i package source non si sviluppano dentro i semantic model consumer
- lo split fisico in repo distinte e obiettivo futuro, non precondizione per lavorare bene adesso

## Cartelle transitorie

- `pbi-finance-domain`
- `pbi-marketing-domain`
- `pbi-modular-platform`
- [REPO_TOPOLOGY.md](../REPO_TOPOLOGY.md)

Questi elementi rappresentano lo scaffolding di migrazione e vanno mantenuti coerenti con gli asset attivi, ma non implicano ancora uno split definitivo.
