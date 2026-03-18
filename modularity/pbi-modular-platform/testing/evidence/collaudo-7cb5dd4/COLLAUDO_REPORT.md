# Collaudo framework modularity - lifecycle install / diff / upgrade / rollback

- Commit collaudato: `7cb5dd4`
- Contesto esecuzione: `workspace locale derivato da 7cb5dd4 con hardening non ancora committato su write/retry filesystem e harness di collaudo`
- Data esecuzione: `2026-03-18 20:30:08`
- Operatore: `ukg15381`
- Runtime shell: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`

## 1. Test eseguiti

### TEST-1 - Installazione pulita modulo
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `20260317_Product_Analysis_FlexTable.pbip`
- Modulo: `flex_table_flat_mvp`
- Versioni: `n/a -> 0.2.0`

### TEST-2 - Diff modulo
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `20260317_UAT_001.pbip`
- Modulo: `finance_compare_mvp`
- Versioni: `0.1.0 -> 0.1.0 (drift controllato)`

### TEST-3 - Upgrade modulo
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `20260317_UAT_001.pbip`
- Modulo: `finance_compare_mvp`
- Versioni: `0.1.0 -> 0.1.1`

### TEST-4 - Rollback modulo
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `20260317_UAT_001.pbip`
- Modulo: `finance_compare_mvp`
- Versioni: `0.1.1 -> 0.1.0`

### TEST-5 - Verifica impatto sul consumer
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `20260317_Product_Analysis_FlexTable.pbip / 20260317_UAT_001.pbip`
- Modulo: `flex_table_flat_mvp / finance_compare_mvp`
- Versioni: `0.2.0 / 0.1.0->0.1.1`

### TEST-6 - Quality checks platform
- Data: `2026-03-18`
- Operatore: `ukg15381`
- Consumer: `repo-wide / 20260317_UAT_001.pbip smoke copy`
- Modulo: `finance_compare_mvp / flex_table_flat_mvp`
- Versioni: `catalog current`

## 2. Esito per test

### TEST-1 - PASS WITH WARNING
- Sintesi: Installazione completata per flex_table_flat_mvp su 20260317_Product_Analysis_FlexTable; metadata e footprint materializzati correttamente.
- Nota: Governance WARN: il repo-health hook non e' compatibile con Windows PowerShell 5.1 e degrada l'operazione.
- Nota: L'apertura in Power BI Desktop non e' verificabile da CLI nel perimetro di questo collaudo.
- Evidenza: `test-1-install-clean\command.txt`
- Evidenza: `test-1-install-clean\command-output.txt`
- Evidenza: `test-1-install-clean\install-log.jsonl`
- Evidenza: `test-1-install-clean\installed-modules.before.json`
- Evidenza: `test-1-install-clean\installed-modules.after.json`
- Evidenza: `test-1-install-clean\files-touched.txt`
- Evidenza: `test-1-install-clean\post-install.git-diff.txt`
- Evidenza: `test-1-install-clean\quality-check.output.txt`

### TEST-2 - PASS
- Sintesi: Diff leggibile e coerente su finance_compare_mvp: rilevate tre derive controllate su semantic asset e report asset del consumer.
- Evidenza: `test-2-diff-module\command.txt`
- Evidenza: `test-2-diff-module\command-output.txt`
- Evidenza: `test-2-diff-module\diff.json`
- Evidenza: `test-2-diff-module\diff.md`
- Evidenza: `test-2-diff-module\files-involved.txt`
- Evidenza: `test-2-diff-module\manual-validation.md`

### TEST-3 - PASS WITH WARNING
- Sintesi: Upgrade completato da finance_compare_mvp 0.1.0 a 0.1.1; consumer e metadata restano coerenti e il progetto supera i quality checks strutturali.
- Nota: Governance WARN: il repo-health hook non e' compatibile con Windows PowerShell 5.1 e degrada l'operazione.
- Nota: Il footprint registrato in metadata rappresenta il perimetro gestito del modulo, non il delta minimo puntuale del singolo upgrade.
- Nota: L'apertura in Power BI Desktop non e' verificabile da CLI nel perimetro di questo collaudo.
- Evidenza: `test-3-upgrade-module\command.txt`
- Evidenza: `test-3-upgrade-module\command-output.txt`
- Evidenza: `test-3-upgrade-module\upgrade-log.jsonl`
- Evidenza: `test-3-upgrade-module\installed-modules.before.json`
- Evidenza: `test-3-upgrade-module\installed-modules.after.json`
- Evidenza: `test-3-upgrade-module\files-touched.txt`
- Evidenza: `test-3-upgrade-module\post-upgrade.git-diff.txt`
- Evidenza: `test-3-upgrade-module\quality-check.output.txt`

### TEST-4 - PASS WITH WARNING
- Sintesi: Rollback eseguito con successo: i file gestiti ritornano al baseline pre-upgrade, mentre gli artifact di audit restano intenzionalmente in module-config.
- Nota: Il rollback ripristina i file gestiti del consumer; restano solo artifact di audit sotto module-config (log, diff, snapshot, repo-health).
- Evidenza: `test-4-rollback-module\command.txt`
- Evidenza: `test-4-rollback-module\command-output.txt`
- Evidenza: `test-4-rollback-module\rollback-log.jsonl`
- Evidenza: `test-4-rollback-module\installed-modules.before-upgrade.json`
- Evidenza: `test-4-rollback-module\installed-modules.after-upgrade.json`
- Evidenza: `test-4-rollback-module\installed-modules.after-rollback.json`
- Evidenza: `test-4-rollback-module\baseline-vs-rollback-managed-diff.txt`
- Evidenza: `test-4-rollback-module\quality-check.output.txt`

### TEST-5 - PASS WITH WARNING
- Sintesi: Il footprint dei moduli e' misurabile e spiegabile; nei casi collaudati non emergono tocchi a tabelle core non modulari.
- Nota: Il modulo tocca file centrali di orchestrazione del progetto (model.tmdl e/o pages.json), quindi l'impatto non e' minimo.
- Evidenza: `test-5-consumer-impact\impact-summary.json`
- Evidenza: `test-5-consumer-impact\impact-summary.md`
- Evidenza: `test-1-install-clean\files-touched.txt`
- Evidenza: `test-3-upgrade-module\files-touched.txt`

### TEST-6 - PASS
- Sintesi: Manifest, regole architetturali, controlli report e smoke-install risultano eseguibili e coerenti sul commit 7cb5dd4.
- Evidenza: `test-6-quality-checks\list-rules.output.txt`
- Evidenza: `test-6-quality-checks\test-module.finance.output.txt`
- Evidenza: `test-6-quality-checks\test-module.marketing.output.txt`
- Evidenza: `test-6-quality-checks\test-repo.output.txt`
- Evidenza: `test-6-quality-checks\smoke-install.output.txt`
- Evidenza: `test-6-quality-checks\quality-summary.json`

## 3. Gap residui

- La verifica di apertura in Power BI Desktop non rientra nel perimetro CLI e resta un controllo operativo da completare su pilot umano.
- Il hook repo-health non e' compatibile con Windows PowerShell 5.1: durante install e upgrade la governance degrada a WARN per parsing degli operatori '??' in repository-health.
- Il rollback ripristina i file gestiti del consumer ma conserva artefatti di audit in module-config, comportamento coerente ma da esplicitare nel runbook.

## 4. Raccomandazione finale

- Esito raccomandato: `framework pronto per pilot tecnico`
- Distribuzione stati: PASS=2; PASS WITH WARNING=4; FAIL=0

## Nota architetturale

Il collaudo e' stato eseguito assumendo che l'architettura corrente sia una modularizzazione per materializzazione controllata nel consumer, non una composizione senza stato risultante. Il criterio di esito non e' quindi l'assenza di stato installato, ma la verifica che lo stato resti minimo, tracciato, coerente, reversibile e governato.
