# Guided Binding Design

## Problema

I moduli tabellari attuali sono riusabili solo entro un contract canonico rigido perche:

- il manifest richiede misure e colonne con nomi fissi
- gli asset `.tmdl` referenziano direttamente quei nomi
- i report `.json` puntano a campi specifici
- il mapping oggi e salvato come metadata, ma non viene applicato agli asset

Questo rende il framework corretto per un core standardizzato, ma poco usabile quando il consumer ha naming diverso.

## Obiettivo

Rendere installabili moduli come `flex_table_flat_mvp` e `flex_metrics_table_mvp` senza chiedere all'utente di compilare a mano JSON tecnici, mantenendo:

- installazione deterministica
- stato installato tracciato e versionato
- diff e rollback affidabili
- supporto a semantic model con naming diversi

## Principio architetturale

L'utente non deve mappare riferimenti tecnici grezzi. Deve associare ruoli semantici a oggetti reali del model. Il framework salva il profilo di mapping e genera gli asset installabili.

## Architettura proposta

### 1. Contract del modulo a ruoli

I moduli cross-domain non dichiarano solo `requires.coreMeasures` e `requires.coreColumns`. Dichiarano un `bindingContract` a ruoli.

Esempio:

```json
{
  "bindingContract": {
    "mode": "guided",
    "roles": [
      {
        "id": "actual_measure",
        "kind": "measure",
        "required": true,
        "label": "Actual",
        "description": "Measure per il valore actual",
        "semanticRole": "actual",
        "acceptsDataType": "numeric",
        "suggestions": ["ACT", "Actual", "Sales Actual"]
      },
      {
        "id": "budget_measure",
        "kind": "measure",
        "required": true,
        "label": "Budget",
        "description": "Measure per il valore budget",
        "semanticRole": "budget",
        "acceptsDataType": "numeric",
        "suggestions": ["BDG", "Budget"]
      },
      {
        "id": "month_column",
        "kind": "column",
        "required": true,
        "label": "Month",
        "description": "Colonna calendario usata dai visual",
        "semanticRole": "calendar.month",
        "suggestions": ["MonthStartDay", "Month Date", "Month"]
      }
    ]
  }
}
```

`requires.coreMeasures` e `requires.coreColumns` restano supportati per i moduli legacy e per i core molto standardizzati.

### 2. Wizard di binding

Nuovo flusso:

1. il framework legge il `bindingContract`
2. scansiona il semantic model del consumer
3. costruisce una lista di candidati compatibili per ogni ruolo
4. propone match automatici quando la confidenza e alta
5. chiede conferma o selezione per i casi ambigui
6. salva un mapping profile riusabile
7. genera gli asset installabili

L'interfaccia puo avere due front-end:

- `CLI guided` come primo step implementativo
- futura UI desktop/web che usa lo stesso backend di discovery e salvataggio

Il backend deve essere unico. La UI non deve contenere logica di business.

### 3. Mapping profile persistito

Il risultato del wizard non va scritto a mano in un file generico. Va persistito come profilo governato.

Path proposto:

- `powerbi-projects/module-config/<pbip>/mapping-profiles/<moduleId>/<profileId>.json`

Esempio:

```json
{
  "profileId": "cana-finance-default",
  "moduleId": "generic_flex_table",
  "createdAt": "2026-03-18T18:00:00Z",
  "roles": {
    "actual_measure": {
      "objectType": "measure",
      "value": "ACT Mth"
    },
    "budget_measure": {
      "objectType": "measure",
      "value": "BDG Mth"
    },
    "month_column": {
      "objectType": "column",
      "value": "Month[Month Date]"
    }
  }
}
```

`installed-modules.json` deve poi salvare:

- `bindingProfileId`
- `bindingProfileHash`
- `bindingMode`
- `resolvedBindings`

## Come applicare il binding

### 4. Asset templated, non asset con nomi hardcoded

Per i moduli cross-domain gli asset devono usare placeholder, non riferimenti finali hardcoded.

Esempi:

- nei `.tmdl`: `{{measure.actual_measure}}`
- nei `.json` report: `{{column.month_column}}`

Durante l'install il framework compila gli asset sostituendo i token con gli oggetti reali selezionati.

Questo e il punto chiave: il mapping deve produrre asset validi prima della materializzazione nel consumer.

### 5. Adapter layer generato

Per le misure il framework genera anche un adapter layer module-owned, cosi il report del modulo si appoggia a wrapper stabili.

Esempio di tabella generata:

- `MOD Flex Bindings`

Esempio di misure generate:

```dax
measure 'MOD Flex Bindings'[Actual Value] = [ACT Mth]
measure 'MOD Flex Bindings'[Budget Value] = [BDG Mth]
measure 'MOD Flex Bindings'[Variance Value] = [ACT Mth] - [BDG Mth]
```

Vantaggi:

- il report usa nomi stabili del modulo
- il binding reale resta confinato nell'adapter
- upgrade e rollback sono piu semplici
- la logica del modulo non dipende dal naming raw del consumer

Per le colonne ci sono due pattern:

- `single binding`: patch del report asset verso la colonna reale
- `multi binding` o selezioni dinamiche: generazione di field parameters module-owned

### 6. Discovery e suggestion engine

Il motore di suggerimento deve classificare i candidati usando:

- nome tecnico
- display name
- table name
- data type
- format string
- annotations
- display folder
- regex e alias da manifest
- similarita lessicale

Output minimo per ogni ruolo:

- `exact match`
- `strong suggestion`
- `ambiguous`
- `no candidate`

Se un ruolo e `ambiguous` o `no candidate`, il wizard blocca l'installazione finche l'utente non seleziona.

## Workflow utente

### Installazione guidata

Comando proposto:

```powershell
./Invoke-PbiModularity.ps1 `
  -Command install `
  -ProjectPath <consumer.pbip> `
  -ModuleId generic_flex_table `
  -Interactive
```

Flusso:

1. validazione package
2. discovery del model
3. suggerimento candidate bindings
4. conferma utente
5. salvataggio mapping profile
6. compilazione asset
7. generazione adapter layer
8. installazione normale
9. aggiornamento metadata e log

### Reuse del profilo

Comandi proposti:

```powershell
./Invoke-PbiModularity.ps1 -Command install -ProjectPath <consumer.pbip> -ModuleId generic_flex_table -BindingProfileId cana-finance-default
./Invoke-PbiModularity.ps1 -Command edit-binding -ProjectPath <consumer.pbip> -ModuleId generic_flex_table
./Invoke-PbiModularity.ps1 -Command list-binding-profiles -ProjectPath <consumer.pbip>
```

## Stato installato e lifecycle

Il lifecycle non deve cambiare concettualmente. Deve solo conoscere il profilo di binding.

Ogni install/upgrade deve tracciare:

- profilo usato
- token risolti
- file generati
- adapter objects generati
- impatto sul consumer

`diff-module` deve poter distinguere:

- delta del package source
- delta del binding profile
- delta degli asset compilati

`rollback-module` deve ripristinare:

- file generati
- adapter layer
- stato installato precedente
- profilo associato alla versione precedente

## Perche non fare binding manuale in Power BI Desktop

Questa opzione e utile per authoring locale, ma non come architettura ufficiale:

- non e deterministica
- non e governata dal framework
- non produce metadata affidabili
- rende diff e rollback deboli
- sposta logica critica fuori dal lifecycle

Power BI Desktop puo restare uno strumento di supporto, non il motore ufficiale del binding.

## Compatibilita con l'architettura attuale

Questa evoluzione e compatibile con il framework esistente:

- `Resolve-PbiModuleMapping` diventa il backend dei ruoli e non solo una mappa nome-a-nome
- `Install-PbiModulePackage` continua a orchestrare validate -> snapshot -> apply -> state
- `installed-modules.json` si estende con metadata di binding
- `diff` e `rollback` continuano a lavorare sui file materializzati

Non cambia il principio base della platform: il consumer resta materializzato, ma in modo minimo, tracciato, coerente e reversibile.

## Incrementi consigliati

### Slice 1

- introdurre `bindingContract` nel manifest schema
- introdurre storage dei `mapping-profiles`
- estendere `installed-modules.json` con metadata binding

### Slice 2

- implementare discovery dei candidati
- implementare suggestion engine con scoring semplice
- esporre `suggest-bindings`

### Slice 3

- implementare `install -Interactive` in CLI
- supportare conferma e selezione da terminale

### Slice 4

- introdurre token nei package cross-domain
- compilare `.tmdl` e `.json` prima del copy nel consumer

### Slice 5

- generare adapter layer per le misure
- introdurre field parameters per binding dinamici di colonne

### Slice 6

- introdurre UI grafica sopra il backend gia esistente

## Decisione raccomandata

Per i moduli tabellari la soluzione raccomandata e:

- wizard guidato
- profili di binding persistiti
- asset templated
- adapter layer generato

Non e raccomandato:

- editing manuale del JSON
- installazione con binding vuoto da completare solo in Desktop

