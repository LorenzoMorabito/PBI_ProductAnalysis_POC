# Integrated Product Analysis Core Source

## Scope

Questa cartella contiene la base dati integrata per il semantic model cross-world dei tre mondi legacy:

- Sales
- Promo
- Finance interno

L'integrazione mantiene le fact separate e crea una identita' condivisa tramite dimensioni conformate.

## Output

- Country conformed rows: `3`
- Quarter conformed rows: `17`
- Month rows: `24`
- Portfolio conformed rows: `392`
- Sales fact rows: `256126`
- Promo fact rows: `23339`
- Finance fact rows: `48`

## Integrated Identity

- Country comune: `Country`
- Tempo comune cross-world: `Quarter`
- Tempo finance detail: `Month`
- Identita' portfolio comune: `Portfolio`
- Identita' molecolare comune: `Molecule`

## Common 3-World Perimeter

- Country: `Italy`
- Quarter comune affidabile: `2024Q1 -> 2025Q3`
- Portfolio comune reale: `INVOKANA`, `VOKANAMET`

## Technical Notes

- Promo viene materializzato sul latest snapshot disponibile per ciascun calendar quarter.
- Finance mantiene la grain mensile, ma viene collegato al quarter tramite `Month -> Quarter`.
- La dimensione `Portfolio` conforma Sales, Promo e Finance a livello brand / portfolio business.
- La normalizzazione molecolare corregge la differenza `CANAGLIFOZIN -> CANAGLIFLOZIN`.
