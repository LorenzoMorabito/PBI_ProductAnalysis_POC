# Finance Compare MVP

Primo modulo importabile di prova.

Contiene:
- un adapter layer semantico con wrapper verso le misure core finance
- un selector disconnesso per il confronto `vs BDG` / `vs PY`
- misure derivate per delta assoluto e percentuale
- una pagina PBIR minimale con slicer e KPI

Contract richiesto dal core:
- `[Fin ACT]`
- `[Fin BDG]`
- `[Fin ACT PY]`
- `[T_DIM_MONTH].[MonthStartDay]`

Strategia:
- il modulo usa solo wrapper `Input ...`
- il report pack punta solo agli oggetti del modulo
- il mapping del MVP e' fisso verso il core model attuale
