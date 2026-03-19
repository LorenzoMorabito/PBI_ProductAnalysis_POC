# Core Measures And Development Guidelines

## Scopo

Questo documento definisce:

- quali misure sono davvero core per ciascun mondo del semantic model
- quali varianti temporali devono esistere in modo standard
- come organizzare naming, layering e sviluppo delle measure

Il semantic model attuale contiene gia' tre mondi:

- `Sales`
- `Promo`
- `Finance`

L'obiettivo non e' elencare tutte le measure esistenti, ma distinguere:

- core business measures
- varianti temporali standard
- KPI derivati
- helper / switch / bucket / UX measures

## Stato Attuale Del Modello

### Sales

Le tabelle principali oggi sono:

- `Msr Sales`
- `Msr Sales Switch`
- `Msr Sales Buckets`
- `Msr Sales Buckets LP`
- `SwitchMeasureSelector (Sales)`
- `SwitchPeriodMode`

Osservazioni:

- il selector business espone oggi solo `Units` e `Values`
- il modello ha gia' `LP`, `PY`, `YTD`, `MAT (4Q)` e varianti rolling
- molte misure LP sono sparse fra `Msr Sales` e `Msr Sales Switch`

### Promo

Le tabelle principali oggi sono:

- `Msr Promo`
- `Msr Promo LP`
- `Msr Promo Switch`
- `Msr Promo Buckets`
- `Msr Promo Buckets LP`
- `Msr Promo MEN`
- `SwitchMeasureSelector (Promo)`
- `SwitchPeriodMode`

Osservazioni:

- il selector business espone oggi `Spending`, `Details`, `Contacts`, `Weighted Calls`
- il modello ha gia' `LP`, `PY`, `YTD`, `MAT (4Q)` per il layer switch
- alcune misure LP sono duplicate fra `Msr Promo` e `Msr Promo LP`
- `Promo NPS` oggi e' implementata come somma di `NPS all channels`: va validata semanticamente

### Finance

Le tabelle principali oggi sono:

- `Msr Fin`
- `Msr Fin LP`
- `Msr Fin Switch`
- `Msr Fin Buckets`
- `Msr Fin Buckets LP`
- `SwitchCompareMode (Finance)`

Osservazioni:

- le business measures core attuali sono poche e corrette come perimetro
- non esiste oggi un vero layer `YTD` / `MAT`
- il finance nasce mensile, ma le LP attuali sono agganciate al quarter
- `Fin ACT vs PP +/-%` oggi usa `PY` nella formula, quindi il naming e' incoerente con il calcolo

## Classificazione Misure

## 1. Base Measures

Misure additive o quasi-additive direttamente derivate dalla fact.
Sono il primo livello del semantic model e devono essere poche, stabili e riusabili.

## 2. Core KPI

Misure business fondamentali costruite sulle base measures:

- market totals
- share
- variance
- target comparison
- conversion

## 3. Time Intelligence

Varianti temporali standard e confronti coerenti.

## 4. UX / Helper / Bucket / Switch

Misure necessarie per experience, dynamic selection, legends, buckets, ranking, colori.
Non devono inquinare il catalogo core.

## Core Measure Catalogo Proposto

## Sales

### Base measures

| Famiglia | Measure core | Tipo |
|---|---|---|
| Units | `Sales Units` | additiva |
| Values | `Sales Values` | additiva |
| Counting | `Counting Units` | additiva |

### Core KPI

| Famiglia | Measure core | Note |
|---|---|---|
| Market Units | `Market Units` | denominatore market |
| Market Values | `Market Values` | denominatore market |
| Unit Share | `Sales Units MS%` | KPI core |
| Value Share | `Sales Values MS%` | KPI core |
| Menarini Values | `MENARINI Sales Values` | utile per vista target |
| Menarini Value Share | `MENARINI MS%` | utile per vista target |

### Varianti temporali richieste

Per `Sales Units`, `Sales Values`, `Market Units`, `Market Values`, `Sales Units MS%`, `Sales Values MS%`:

- current period
- `LP`
- `PY`
- `Δ vs PY`
- `Δ% vs PY`
- `YTD`
- `YTD PY`
- `YTD Δ`
- `YTD Δ%`
- `MAT4Q`
- `MAT4Q PY`
- `MAT4Q Δ`
- `MAT4Q Δ%`

### Varianti opzionali / analytical

- `3MM`
- `3MM PY`
- `EI base 100`
- TopN / buckets / driver tables

## Promo

### Base measures

| Famiglia | Measure core | Tipo |
|---|---|---|
| Spend | `Promo Spend` | additiva |
| Details | `Promo Details` | additiva |
| Contacts | `Promo Contacts` | additiva |
| Weighted Calls | `Promo Weighted Calls` | additiva |
| Quality | `Promo Quality Index` | da validare come aggregazione business |

### Core KPI

| Famiglia | Measure core | Note |
|---|---|---|
| Market Spend | `Market Spend (ATC4 - Total)` | denominatore promo |
| Market Details | `Market Promo Product Details` | denominatore promo |
| Share of Voice | `Promo SOV%` | KPI core |
| Share of Voice ATC4 | `Promo SOV% (ATC4)` | KPI core |
| ESOV | `Promo ESOV` | KPI core |
| Cost Efficiency | `Promo Spend €/1k Details` | KPI core |
| Spend Share | `% Share of Spend` | KPI core |
| Spend per Unit | `Promo Spend €/1k Units` | cross-world KPI |
| Positive Calls | `Promo Calls with Positive Prescribing` | KPI core opzionale |
| Positive Contacts | `Promo Contacts with Positive Prescribing` | KPI core opzionale |
| Conversion Calls | `Promo Conversion Rate Calls %` | KPI core opzionale |
| Conversion Contacts | `Promo Conversion Rate Contacts %` | KPI core opzionale |

### Misura da validare

`Promo NPS` non dovrebbe essere trattata come core fino a validazione.
Nel modello attuale e' implementata come:

- somma di `NPS all channels`

Questo puo' essere corretto solo se il campo sorgente e' gia' un indicatore aggregabile. Se invece e' un score/precomputed bucket, la misura va ripensata.

### Varianti temporali richieste

Per `Promo Spend`, `Promo Details`, `Promo Contacts`, `Promo Weighted Calls`, `Promo SOV%`, `Promo ESOV`, `Promo Spend €/1k Details`:

- current period
- `LP`
- `PY`
- `Δ vs PY`
- `Δ% vs PY`
- `YTD`
- `YTD PY`
- `YTD Δ`
- `YTD Δ%`
- `MAT4Q`
- `MAT4Q PY`
- `MAT4Q Δ`
- `MAT4Q Δ%`

### Varianti opzionali / analytical

- percentile / benchmark bands
- Menarini-only promo views
- TopN / bucket / benchmark visuals

## Finance

### Base measures

| Famiglia | Measure core | Tipo |
|---|---|---|
| Actual | `Fin ACT` | additiva |
| Budget | `Fin BDG` | additiva |

### Core KPI

| Famiglia | Measure core | Note |
|---|---|---|
| ACT vs BDG abs | `Fin ACT vs BDG abs` | KPI core |
| ACT vs BDG % | `Fin ACT vs BDG +-%` | KPI core |
| ACT PY | `Fin ACT PY` | baseline PY |
| BDG PY | `Fin BDG PY` | opzionale, da confermare business |
| ACT vs PY % | `Fin ACT vs PY PPG%` | KPI core |

### Incoerenza attuale da correggere

`Fin ACT vs PP +/-%` nel modello attuale usa `Fin ACT PY` e quindi non rappresenta davvero il previous period.

Prima di renderla parte del catalogo core occorre decidere:

- `PP` = previous month
- oppure `PP` = previous quarter

e implementarla coerentemente.

### Varianti temporali richieste

Poiche' la fact finance e' mensile, il time frame standard dovrebbe essere mensile e non quarter-based per default.

Per `Fin ACT`, `Fin BDG`, `Fin ACT vs BDG abs`, `Fin ACT vs BDG %`, `Fin ACT vs PY %`:

- current month
- `LM` oppure `LP` se il perimetro e' chiaramente mensile
- `PY`
- `Δ vs PY`
- `Δ% vs PY`
- `YTD`
- `YTD PY`
- `YTD Δ`
- `YTD Δ%`
- `MAT12M`
- `MAT12M PY`
- `MAT12M Δ`
- `MAT12M Δ%`

### Se servono viste quarter

Non usare un generico `LP` ambiguo.
Se servono misure quarter-based per finance, definire esplicitamente:

- `Fin ACT LQ`
- `Fin ACT QTD`
- `Fin ACT QTD PY`
- `Fin ACT MAT4Q`

solo per le pagine che lavorano davvero a quarter.

## Politica Dei Time Frame

## Sales

- grain nativo: quarter
- `LP` = last available quarter
- `YTD` = quarter YTD
- `MAT` = `MAT4Q`

## Promo

- grain semantico attuale: quarter
- `LP` = last available quarter
- `YTD` = quarter YTD
- `MAT` = `MAT4Q`

## Finance

- grain nativo: month
- `LP` non deve essere usato da solo se il consumatore non sa che significa `last month`
- preferire:
  - `LM` per last month
  - `LQ` per last quarter
  - `MAT12M` per moving annual total

## Naming Convention Raccomandata

## Principio

Il nome deve essere leggibile, gerarchico e corto.
Non deve sembrare un codice a barre, ma nemmeno un titolo parlato.

## Pattern consigliato

`<Domain> <Metric> [Scope] [TimeFrame] [Compare]`

Ordine consigliato:

1. dominio
2. metrica
3. perimetro o scope
4. finestra temporale
5. confronto

## Esempi buoni

- `Sales Units`
- `Sales Units LP`
- `Sales Units PY`
- `Sales Units YTD`
- `Sales Units MAT4Q`
- `Sales Units Δ vs PY`
- `Sales Units Δ% vs PY`
- `Sales Values MS%`
- `Promo Spend`
- `Promo Spend LP`
- `Promo Spend MAT4Q`
- `Promo SOV%`
- `Promo ESOV`
- `Finance ACT`
- `Finance ACT LM`
- `Finance ACT YTD`
- `Finance ACT MAT12M`
- `Finance ACT vs BDG %`

## Esempi da evitare

- `Fin ACT vs PP +/-%`
- `Sales Values +/-% vs PY (QTR)`
- `LP Sales Values MS% EI PY (QTR) (ATC4)`
- `Switch Promo Market MAT PY (Dynamic)`

Questi nomi possono esistere in un layer tecnico, ma non dovrebbero rappresentare il catalogo business finale.

## Regole pratiche di naming

- usare un solo dominio per misura: `Sales`, `Promo`, `Finance`
- usare un solo token temporale per volta: `LP`, `YTD`, `MAT4Q`, `MAT12M`, `PY`
- usare `Δ` e `Δ%` oppure `Var` e `Var%`, non entrambe
- evitare `+/-%`, `PPG%`, sigle non spiegate
- mettere `ATC4`, `Target`, `Menarini`, `Market` solo se aggiungono vero significato
- non usare parentesi annidate e suffissi multipli non necessari

## Organizzazione Raccomandata Delle Measure Tables

Per ogni mondo:

- `msr_<world>`
  - solo base measures e core KPI business
- `msr_<world>_lp`
  - solo snapshot `LP` / `LM` / `LQ`
- `msr_<world>_ti`
  - PY, YTD, MAT, rolling, EI
- `msr_<world>_ux`
  - switch, buckets, colours, labels, ranking, helpers

Esempio:

- `msr_sales`
- `msr_sales_lp`
- `msr_sales_ti`
- `msr_sales_ux`

Stesso schema per promo e finance.

## Best Practice Di Sviluppo

## 1. Layering chiaro

- le base measures devono essere semplici aggregazioni
- i KPI devono dipendere solo dalle base measures
- la time intelligence deve dipendere da KPI/base, non da colonne raw
- i selector UX non devono contenere business logic non riusabile

## 2. Una sola definizione per concetto

- una sola misura `Sales Values`
- una sola misura `Promo Spend`
- una sola misura `Fin ACT`

Tutte le altre varianti devono riusare queste misure, non riscrivere formule raw.

## 3. Niente duplicazione LP dispersa

Le misure `LP` non dovrebbero essere sparse fra tabelle core e tabelle dedicate.
Serve una collocazione chiara e unica.

## 4. Esplicitare il grain temporale

Se il dominio e' quarter-based usare `LP`, `YTD`, `MAT4Q`.
Se il dominio e' month-based usare `LM`, `YTD`, `MAT12M`.
Non mischiare i due mondi nello stesso nome.

## 5. Validare le misure non additive

Da verificare sempre:

- NPS
- index
- quality scores
- share
- ESOV

Non tutto cio' che e' numerico e' una misura additive-safe.

## 6. Descrizioni e metadata

Ogni core measure dovrebbe avere:

- descrizione business
- grain
- perimetro
- formato
- owner

## 7. Test minimi

Per ogni famiglia core:

- test no filter
- test by country
- test by product
- test PY
- test YTD
- test MAT
- test LP

## 8. Hardcoded filters solo se dichiarati

Filtri come `MENARINI` o `ATC4` vanno bene se il perimetro e' voluto e dichiarato.
Non devono essere nascosti dentro misure che sembrano generiche.

## Target Raccomandato Di Primo Sprint Sulle Core Measures

## Sales

Rendere ufficiali:

- `Sales Units`
- `Sales Values`
- `Counting Units`
- `Market Units`
- `Market Values`
- `Sales Units MS%`
- `Sales Values MS%`
- relative varianti `LP`, `PY`, `YTD`, `MAT4Q`

## Promo

Rendere ufficiali:

- `Promo Spend`
- `Promo Details`
- `Promo Contacts`
- `Promo Weighted Calls`
- `Promo SOV%`
- `Promo ESOV`
- `Promo Spend €/1k Details`
- relative varianti `LP`, `PY`, `YTD`, `MAT4Q`

Mettere `Promo Quality Index` e `Promo NPS` in stato:

- `to validate`

## Finance

Rendere ufficiali:

- `Finance ACT`
- `Finance BDG`
- `Finance ACT vs BDG`
- `Finance ACT vs PY`

e aggiungere:

- `Finance ACT LM`
- `Finance ACT YTD`
- `Finance ACT YTD PY`
- `Finance ACT MAT12M`
- `Finance ACT MAT12M PY`
- `Finance ACT vs BDG YTD`
- `Finance ACT vs PY YTD`

## Conclusione

La direzione corretta e' assolutamente quella di una documentazione sulle core measures per mondo.

La struttura consigliata e':

- star schema e note di dominio
- catalogo core measures
- policy di time frame
- naming convention
- best practice di sviluppo

Questo e' il livello giusto per passare da un semantic model che funziona a un semantic model governabile e scalabile.
