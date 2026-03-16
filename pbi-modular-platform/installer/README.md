# Installer

Planned common commands:
- `list-modules`
- `install-module`
- `upgrade-module`
- `validate-project`

Expected workflow:
1. Read the package catalog from a domain repo.
2. Validate required core measures and columns.
3. Auto-map known canonical inputs.
4. Ask only for missing mappings.
5. Copy semantic assets into the consumer semantic model.
6. Copy page/report assets into the consumer report.
7. Persist installed-module metadata for future upgrades.
