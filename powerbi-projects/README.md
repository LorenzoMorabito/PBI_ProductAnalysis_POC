# Power BI Projects Area

Questa area contiene tutti i progetti `PBIP` attivi del workspace, insieme ai semantic model e ai metadata delle installazioni modulo.

## Progetti presenti

| Progetto | Tipo | Semantic model | Stato |
| --- | --- | --- | --- |
| `20260227_Product_Analysis.*` | consumer storico | dedicato, esteso | progetto originale completo |
| `20260227_Product_Analysis_Core.*` | baseline | core pulito | base di partenza per nuovi consumer |
| `20260317_Product_Analysis_FlexTable.*` | consumer derivato | dedicato, derivato dal core | contiene moduli FlexTable installati |
| `20260317_UAT_001.*` | progetto di test | dedicato, derivato dal core | UAT completato con 3 moduli installati |

## Module config

`module-config/` contiene lo stato installativo dei consumer che hanno moduli gestiti.

Stato attuale:

- `module-config/20260317_Product_Analysis_FlexTable`
- `module-config/20260317_UAT_001`

Il `Core` e il progetto originale non usano oggi `installed-modules.json`.

## Regole operative

- i report e semantic model consumer vivono qui
- gli asset installati dei moduli si tracciano qui
- il semantic core pulito resta la baseline di partenza per nuovi consumer
- i consumer derivati con moduli non devono puntare al semantic model `Core` condiviso

## Comandi utili

Quality check di tutti i progetti:

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```

Validazione di un singolo progetto:

```powershell
./modularity/pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-project `
  -ProjectPath ./powerbi-projects/20260227_Product_Analysis_Core.pbip `
  -FailOnError
```
