# Repository Health Runbook

## Scopo

Questo runbook serve per usare rapidamente il framework `repository-health` in tre casi:

- check veloce locale
- audit completo locale
- lettura del risultato e triage

## 1. Check veloce locale

Usalo prima di un commit importante o dopo un refactor della repo.

```powershell
./repository-health/analyzer.ps1 -Mode local
```

Cosa fa:

- legge le metriche Git principali
- controlla file vietati
- controlla blob storici grandi
- produce output locali

Output principali:

- [metrics.json](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/metrics.json)
- [summary.md](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/summary.md)
- [dashboard.html](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/dashboard.html)

## 2. Check locale bloccante

Usalo se vuoi simulare il comportamento del gate CI.

```powershell
./repository-health/analyzer.ps1 `
  -Mode local `
  -FailOnThresholdBreach
```

Comportamento:

- `OK` o `WARN`: il comando termina normalmente
- `FAIL`: il comando esce con errore

## 3. Audit completo locale

Usalo per una scansione piu profonda, simile al workflow schedulato.

```powershell
./repository-health/analyzer.ps1 `
  -Mode schedule `
  -EnableGitSizer
```

Note:

- se `git-sizer` non e disponibile, il framework continua comunque
- il comando produce anche i dati storici runtime locali

## 4. Come leggere il risultato

### Stato `OK`

- nessuna anomalia significativa
- nessun file vietato
- nessuna soglia critica superata

### Stato `WARN`

- repo utilizzabile
- c'e un punto di attenzione da monitorare

Esempi tipici:

- file corrente piu grande oltre la soglia warning
- crescita anomala rispetto allo snapshot precedente
- `size-pack` sopra threshold di attenzione

### Stato `FAIL`

- presenza di file vietati
- blob storico oltre soglia critica
- violazione bloccante della policy

In caso di `FAIL`, il change non va considerato pronto per merge senza fix o decisione esplicita.

## 5. Triage rapido

### Caso A: warning sul file corrente piu grande

Controlla il summary:

- apri [summary.md](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/summary.md)

Domande da fare:

- il file e testuale e atteso?
- e parte del semantic model o e un artefatto evitabile?
- puo essere spezzato o alleggerito?

### Caso B: file vietati

Controlla se nel working tree sono entrati file come:

- `.pbix`
- `.pbit`
- `.xlsx`
- `.csv`

Azione:

- rimuoverli dal versioning
- spostarli in un path locale escluso
- oppure aggiornare la policy solo se la scelta e intenzionale e approvata

### Caso C: blob storico grande

Il problema e nella storia Git, non solo nello stato corrente.

Azione:

- identificare il blob
- valutare se e tollerabile
- se non lo e, pianificare una bonifica della history separata dal normale sviluppo

## 6. Dove guardare i file

Output correnti:

- [metrics.json](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/metrics.json)
- [summary.md](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/summary.md)
- [dashboard.html](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/current/dashboard.html)

Storico runtime locale:

- [outputs/history](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/outputs/history)

Storico persistente autorevole:

- branch `repo-health-data`
- path target: `repository-health/history/...`

## 7. Uso in CI

### Pull request

Workflow:

- [.github/workflows/repo-health-pr.yml](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/.github/workflows/repo-health-pr.yml)

Comportamento:

- valida la PR
- commenta il summary
- non scrive sul branch storico

### Push su main

Workflow:

- [.github/workflows/repo-health-push.yml](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/.github/workflows/repo-health-push.yml)

Comportamento:

- esegue analisi
- aggiorna il branch `repo-health-data`

### Audit schedulato

Workflow:

- [.github/workflows/repo-health-schedule.yml](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/.github/workflows/repo-health-schedule.yml)

Comportamento:

- esegue analisi approfondita
- prova anche `git-sizer`
- aggiorna lo storico persistente

## 8. Comandi da ricordare

Check veloce:

```powershell
./repository-health/analyzer.ps1 -Mode local
```

Check bloccante:

```powershell
./repository-health/analyzer.ps1 -Mode local -FailOnThresholdBreach
```

Audit completo:

```powershell
./repository-health/analyzer.ps1 -Mode schedule -EnableGitSizer
```

## 9. Regola pratica

Per il lavoro quotidiano:

1. lancia `-Mode local`
2. se esce `WARN`, leggi `summary.md`
3. se esce `FAIL`, non procedere al merge senza fix
4. lascia ai workflow GitHub la persistenza storica su `repo-health-data`
