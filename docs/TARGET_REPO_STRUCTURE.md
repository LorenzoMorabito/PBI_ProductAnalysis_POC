# Target Repo Structure

Data decisione: `2026-03-17`

## Principio

La repo attuale non va ancora spezzata fisicamente in modo aggressivo, per non rompere i workflow PBIP attivi.

La struttura target va perseguita in due tempi:

- `Fase 1`: chiarezza concettuale dentro la repo attuale
- `Fase 2`: split fisico in repo distinte quando installer, package lifecycle e consumer contract saranno stabili

## Struttura target concettuale

### 1. Consumer projects

Asset PBIP usati dal team:

- `20260227_Product_Analysis.*`
- `20260227_Product_Analysis_Core.*`
- `20260317_Product_Analysis_FlexTable.*`

Ruoli:

- `Product_Analysis`: consumer storico completo
- `Product_Analysis_Core`: baseline pulita
- `Product_Analysis_FlexTable`: consumer derivato con semantic model dedicato

### 2. Domain package sources

- `pbi-finance-domain`
- `pbi-marketing-domain`

Ruolo:

- ospitare solo i package source e, in futuro, i consumer di dominio gia stabilizzati

### 3. Shared platform

- `pbi-modular-platform`

Ruolo:

- installer
- quality checks
- schemi metadata
- lifecycle docs

## Gerarchia finale raccomandata

### Repo 1: consumer workspace

Contiene:

- consumer attivi
- semantic model derivati installati
- `module-config`

Non contiene:

- sorgenti package come punto di authoring principale
- piattaforma tecnica comune

### Repo 2: modular platform

Contiene:

- installer
- validation framework
- schemi JSON
- CI support
- lifecycle docs

### Repo 3: finance domain

Contiene:

- package finance
- eventuali finance consumer futuri

### Repo 4: marketing domain

Contiene:

- package marketing
- eventuali marketing consumer futuri

## Struttura operativa raccomandata nella repo attuale

Finche non si fa lo split fisico, la regola da seguire e:

- i PBIP attivi restano in root
- `pbi-finance-domain`, `pbi-marketing-domain`, `pbi-modular-platform` restano cartelle transitorie ma autorevoli per il loro perimetro
- gli asset installati restano nel consumer project che li usa

Questa e la struttura da leggere come ufficiale:

```text
/
  20260227_Product_Analysis*
  20260227_Product_Analysis_Core*
  20260317_Product_Analysis_FlexTable*
  module-config/
  pbi-finance-domain/
  pbi-marketing-domain/
  pbi-modular-platform/
  docs/
```

## Cosa non fare ora

- non spostare i PBIP attivi sotto nuove sottocartelle senza una fase di migrazione esplicita
- non creare una repo per ogni singolo package
- non introdurre riferimenti live tra repo che propagano modifiche in automatico ai consumer

## Trigger per lo split fisico

Lo split in repo distinte va eseguito solo quando sono vere tutte queste condizioni:

- installer stabile con `install` e `upgrade`
- metadata moduli affidabili
- contract `core vs module` approvato
- almeno un consumer derivato gestito con successo
- team allineato sul workflow Git e PBIP

## Verdetto

Il refactor della root e giusto, ma la forma corretta adesso e:

- `contract first`
- `migration later`

Quindi:

- subito: chiarezza documentale e architetturale
- dopo: spostamento fisico controllato
