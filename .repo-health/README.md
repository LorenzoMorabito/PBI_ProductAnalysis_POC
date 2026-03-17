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
./.repo-health/analyzer.ps1 `
  -Mode local `
  -FailOnThresholdBreach
```

## Output

Generati in `.repo-health/outputs/`:

- `current/metrics.json`
- `current/summary.md`
- `history/latest.json`
- `history/metrics-history.csv`
- `current/git-sizer.txt` se abilitato e disponibile

## Workflow GitHub Actions

- `.github/workflows/repo-health-pr.yml`: validazione PR con gate bloccante e commento automatico
- `.github/workflows/repo-health-push.yml`: monitoraggio su push verso `main`
- `.github/workflows/repo-health-schedule.yml`: audit pianificato con integrazione `git-sizer` opzionale

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
