# Product Analysis Integrated Core Semantic Model

## Scopo

Questo semantic model integra i tre mondi legacy `Sales`, `Promo` e `Finance` in un unico semantic layer, mantenendo le fact separate e creando una identita' condivisa tramite dimensioni conformate.

Base dati integrata:

- `C:\work\MEN_Marketing\PBI_ProductAnalysis_POC\data_source\Integrated Product Analysis Core\semantic_source`

Obiettivo funzionale:

- mantenere i tre layer core legacy separati nelle misure
- offrire un asse comune `Country + Quarter + Portfolio + Molecule`
- evitare switch, slicer custom e oggetti UX composti
- creare una baseline integrata da cui derivare il semantic model ufficiale cross-world

## Struttura del modello

Tabelle visibili:

- `Country`
- `Quarter`
- `Month`
- `Portfolio`
- `Molecule`
- `Sector`
- `Diagnosis`
- `Specialty`
- `Channel`
- `Feedback`
- `Sales`
- `Promo`
- `Finance`

Tabelle nascoste:

- `F_Sales`
- `F_Promo`
- `F_Finance`
- `Sales Product`
- `Promo Product`
- `Finance Product`
- `B_PortfolioMolecule`

## Integrated Identity

- `Country` e' conformata sui tre mondi
- `Quarter` e' la dimensione tempo comune per dashboard cross-world
- `Month` mantiene il dettaglio finance e si collega a `Quarter`
- `Portfolio` e' la chiave business comune di integrazione
- `Molecule` filtra cross-world tramite il bridge `Portfolio -> Molecule`

## Common 3-World Perimeter

- Country comune reale: `Italy`
- Finestra quarter affidabile: `2024Q1 -> 2025Q3`
- Portfolio comune reale: `INVOKANA`, `VOKANAMET`

## Note tecniche

- `Sales` e `Promo` restano quarter-centric.
- `Finance` mantiene la grain mensile, ma puo' essere filtrato da `Quarter` tramite la relazione `Quarter -> Month -> F_Finance`.
- `Promo` viene materializzato sul latest snapshot disponibile per ciascun calendar quarter.
- I nomi delle misure restano quelli business/OAS dei tre core legacy.
- Le misure core di ciascun mondo restano separate nelle tabelle `Sales`, `Promo` e `Finance`.
