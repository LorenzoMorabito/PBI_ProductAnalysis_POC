# Repo Health Framework

Framework automatico di monitoraggio della salute Git della repository, progettato per repository Power BI in formato `PBIP`.

## Obiettivi coperti

- prevenzione del repository bloat
- monitoraggio della crescita Git nel tempo
- identificazione di file vietati e pattern critici
- evidenza quantitativa dell'impatto del versioning testuale
- base tecnica per standard aziendale `Power BI + Git`

## Uso locale

```powershell
./repository-health/analyzer.ps1 `
  -Mode local `
  -FailOnThresholdBreach
```

Runbook operativo rapido:

- [RUNBOOK.md](C:/work/MEN_Marketing/PBI_ProductAnalysis_POC/repository-health/RUNBOOK.md)

## Configurazione

Parametri principali in `config.json`:

- `data_branch_name`: branch autorevole per la telemetria storica
- `history_root_relative_path`: radice dati persistenti nel branch storico
- `max_blob_mb`, `max_pack_mb`, `max_growth_pct`: threshold di controllo
- `forbidden_extensions`: estensioni bloccanti
- `excluded_paths`: path esclusi dalla working tree scan
- `allowed_tracked_excluded_paths`: eccezioni esplicite ai placeholder versionati

## Output

Generati in `repository-health/outputs/`:

- `current/metrics.json`
- `current/summary.md`
- `history/latest.json`
- `history/metrics-history.csv`
- `current/git-sizer.txt` se abilitato e disponibile

## Workflow GitHub Actions

- `.github/workflows/repo-health-pr.yml`: validazione PR con gate bloccante e commento automatico
- `.github/workflows/repo-health-push.yml`: monitoraggio su push verso `main`
- `.github/workflows/repo-health-schedule.yml`: audit pianificato con integrazione `git-sizer` opzionale

## Level 2 Persistence

Il framework ora usa un modello a due branch:

- `main`: codice, configurazione, workflow
- `repo-health-data`: storico persistente, auditabile e diffabile

Nel branch `repo-health-data` la struttura target è:

```text
repository-health/
  history/
    latest.json
    metrics-history.csv
    runs/
      2026-03-18T10-00-00Z.json
      2026-03-18T10-00-00Z.md
    git-sizer/
      2026-03-18T10-00-00Z.txt
```

### Comportamento per workflow

- `pull_request`: legge il baseline storico ma non scrive
- `push` su `main`: aggiorna lo storico sul branch dati
- `schedule` / `workflow_dispatch`: aggiorna lo storico e salva anche `git-sizer` quando disponibile

### Script operativi

- `scripts/Prepare-RepoHealthDataBranch.ps1`: prepara o bootstrap la worktree del branch dati
- `scripts/Publish-RepoHealthDataBranch.ps1`: committa e pusha la telemetria nel branch dati

## Bootstrap

Il primo deploy supporta automaticamente il caso in cui `repo-health-data` non esista ancora:

1. il workflow prepara una worktree temporanea
2. crea un branch orfano `repo-health-data`
3. inizializza `repository-health/history`
4. persiste `latest.json`, `metrics-history.csv` e il primo snapshot `runs/*`

L’analyzer non fallisce se lo storico non esiste ancora.

## Policy

`FAIL`

- file vietati presenti nel working tree versionabile
- file tracked in cartelle escluse
- blob storico oltre `max_blob_mb`

`WARN`

- `size-pack` oltre soglia
- crescita anomala rispetto al baseline precedente
- file corrente più grande oltre soglia warning

## Esempio summary

```text
Repository Health Check
  Status: OK
  Branch: main
  Size pack: 0.34 MB
  Largest blob: 1.63 MB
  Blob > 1 MB: 2
  Forbidden files: 0
```

## Esempio JSON

```json
{
  "repository": "LorenzoMorabito/PBI_ProductAnalysis_POC",
  "git_core": {
    "size_pack_mb": 0.34,
    "object_count": 1064,
    "packed_object_count": 1064,
    "pack_count": 2
  },
  "history": {
    "max_blob_mb": 1.63,
    "blob_over_1mb": 2,
    "blob_over_5mb": 0
  },
  "policy": {
    "status": "OK"
  }
}
```

## Troubleshooting

### Loop automatici

I workflow non si autoinnescano perché:

- il trigger di `push` ascolta solo `main`
- i job hanno un guardrail esplicito contro `refs/heads/repo-health-data`
- nessun workflow scrive mai su `main`

### Permessi

- `repo-health-pr.yml`: `contents: read`, `pull-requests: write`
- `repo-health-push.yml`: `contents: write`
- `repo-health-schedule.yml`: `contents: write`, `issues: write`

### Failure di persistenza

Se il push verso `repo-health-data` fallisce:

- il summary runtime resta disponibile
- l’artifact resta disponibile
- il warning viene scritto nel `GITHUB_STEP_SUMMARY`
- la failure di persistenza non maschera l’esito dell’analisi

### Upgrade da storico legacy

Se esiste un `metrics-history.csv` con schema precedente, il framework lo ruota automaticamente in un file `*.legacy-<timestamp>.csv` e crea un nuovo CSV Level 2.
