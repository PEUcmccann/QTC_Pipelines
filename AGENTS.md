## About this repo

This repo holds Qlik Talend Cloud (QTC) Data Integration project exports. Each export is a folder `<PROJECT>_<timestamp>_ALL/`. The oldest export, `QTC_DEV_SAP_RAW_INGESTION`, lands SAP HANA view `ZFCST_A03` into the Snowflake DEV_RAW `SAP` schema.

## Gotchas

- The tenant project name has an `N/A_` prefix: `N/A_QTC_DEV_SAP_RAW_INGESTION` (ID `6a3e67b918025aff04727251`). The export name does not.
- Task IDs, such as `-lpag` and `-lpah`, are part of the variable names in `bindings.json`. If you rename a task, its bindings break.
- Do not edit an old export by hand. Replace it with a fresh export from QTC. A new project starts from files you write: import it, then export it again.
- Do not commit secrets or passwords. Connections are bound by name in `bindings.json`.
- The storage task schedule (`Onboarding_Storage`, every 15 minutes) is disabled. Unknown why. Ask before you enable it.

## Qlik tooling

- Use the Qlik MCP for read-only work: project details, bindings, lineage, dataset profile and freshness.
- Use the `qlik` CLI for project export, validate and import.
- Name the context in every command: `--context pilgrims` (EU tenant). Do not rely on the default.
- Free to run: `ls`, `get`, `export`, `validate`. Ask first before `import`, `prepare`, or any command that starts or stops a task or a reload.
- A request to land data counts as approval for `import`, `prepare` and task runs. This applies only in a project you create for it. Ask first before you touch an existing project.
- New SAP BW view: copy an export of `SAP_BW_C_BILLINGDOCUMENTPRICINGCONDITION` (DEV space). Build, import and watch with the scripts in `scripts/`. Steps and failure signs: `docs/qtc-import.md`. A load that times out in HANA: `docs/bom-slicing.md`.
- Sliced view, or a build in PROD: `docs/bom-slicing.md`.
- Export a project: `qlik di-project export <id> --context pilgrims --mode ALL --includeBindings --output-file <file>.zip`. Unzip into a new folder named `<PROJECT>_<timestamp>_ALL`. Check the result against the last export before you commit.
- The exports in this repo stay the source of truth. After a change in the tenant, export again into a new folder.

## Before you open a pull request

Run `qlik di-project validate <id> --context pilgrims`. It must pass. Put the result in the pull request body.

## Writing to Git

Before you write text to Git or GitHub, apply the text rules in `CODING_STANDARDS.md`. This covers issues, comments, wayfinder maps, commit messages and pull request bodies.

## Pull requests

Start each pull request title with one type word and a colon, for example `Add: storage task for ZFCST_A03`.

| Type | Use it when |
| --- | --- |
| `Add` | The pull request adds a new export, task or dataset. |
| `Fix` | A task setting was wrong. |
| `Change` | A decided rule changes a task. The old setting was not wrong. |
| `Research` | The pull request adds notes only. |
| `Docs` | The pull request changes documentation. |
| `Tooling` | The pull request changes CI or scripts. |

- Use one type for each pull request. The rules for reviewers are in `CODING_STANDARDS.md`.
- Branch from `main`. Use a short branch name.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (PEUcmccann/QTC_Pipelines) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.
