# Workflow

## Regole Git minime

- ogni lavoro va fatto su branch dedicato
- merge verso `main` solo via pull request
- niente commit diretti su `main` salvo attivita di manutenzione concordate

Convenzione branch consigliata:

- `feature/<scope>`
- `fix/<scope>`
- `chore/<scope>`
- `docs/<scope>`

## Convenzione commit consigliata

- messaggi brevi, tecnici e leggibili
- descrivere il cambiamento reale, non l'intenzione generica

Esempi:

- `Stabilize root documentation and workflow`
- `Neutralize local path parameter in semantic model`
- `Separate FlexTable into derived semantic model`

## Definition of Done PBIP

Ogni change PBIP deve rispettare questi check minimi:

- il progetto si apre in Power BI Desktop
- non vengono committati artefatti locali sotto `.pbi/`
- non vengono committati path locali reali non approvati
- il diff e leggibile e spiegabile
- se cambia il setup, viene aggiornata la documentazione

## Check minimi prima del merge

### Quality checks

```powershell
./pbi-modular-platform/testing/Invoke-PbiQualityChecks.ps1 `
  -Command test-repo `
  -FailOnError
```

### Controllo stato Git

```powershell
git status --short
```

### Apertura manuale Power BI Desktop

Aprire almeno il progetto toccato dal change e verificare:

- caricamento corretto
- assenza di errori visual
- assenza di mismatch tra report e semantic model

## Regole operative PBIP

- il `Core` deve restare baseline pulita
- un consumer con moduli installati non deve puntare al semantic model core condiviso
- i package source si modificano nei folder domain
- gli asset installati si tracciano nel consumer tramite `module-config`
