# Build and import a QTC project from files

This note covers a new SAP BW replication project. It explains the order of steps and the failure signs. The scripts are in `scripts/`.

## Start from a template

Export `SAP_BW_C_BILLINGDOCUMENTPRICINGCONDITION` from the DEV space (ID `6ac8bd74fe38dc65085c2c9e`). It has one replication task, full load only. Source: `DEV.DEV_SRC_SAP_HBP_BW`. Target: `DEV.DEV_TGT_SNOWFLAKE_DEV_RAW`, schema `SAP`.

Copy the column types from the matching `PROD_RAW.SAP` table. The dataset file needs a full `tableDef`.

## Steps

1. Create the project: `qlik di-project create --context pilgrims --type DATA_MOVEMENT --platformType NONE --space <DEV space ID> --name <NAME>`.
2. Pack and validate: `pwsh scripts/pack-project.ps1 -Folder <project folder>`. The report must be empty.
3. Import: `pwsh scripts/import-project.ps1 -ProjectId <id> -Zip <zip> -VarsFile <vars.json>`.
4. Validate and prepare the project. Both must show `failed: 0`.
5. Start the smallest task first. Then start the rest.
6. Watch progress: `pwsh scripts/watch-tasks.ps1 -ProjectId <id>`.
7. Export the project into a new folder `<PROJECT>_<timestamp>_ALL`.

`vars.json` has `nameToIdMap` (connection name to ID) and `variables`. Write it as UTF-8 without BOM. Use the output of `qlik di-project export-variables get <reference project ID> --context pilgrims` as a model.

## Failure signs

| Sign | Cause | Action |
| --- | --- | --- |
| Import fails with "required bindings are missing" | The first import into a new project always fails. | `import-project.ps1` sets the variables and imports again. |
| The same error again | A BOM in a JSON file, or a zip with `\` in entry names. | Use `pack-project.ps1`. |
| "Operation PROJECT_IMPORT already exists" | The project holds an import lock. The API cannot clear it or delete the project. | Create a new project. Delete the old one in the Qlik Cloud UI. |
| A task is `NOT_RUNNABLE` with "Not found" after prepare | The gateway task did not deploy. | `qlik di-project di-task prepare --di-projectId <id> --di-taskId <task> --allowRecreate`. |
| A full load shows no rows after 10 minutes | HANA times out on the whole view. | Slice the load. See `docs/bom-slicing.md`. |

## Notes

- `runtime state` shows full-load counts only in `lastRun.fullLoad`. Run history stays empty until a run ends.
- Action states include `EXECUTING`. Wait for `COMPLETED` or `FAILED`.
- Each slice task truncates its table before it loads.
- For a PROD build from a DEV export, follow the steps in `docs/bom-slicing.md`.
- Project prepare can report `failed: 0` while the tasks stay `NOT_RUNNABLE` with an empty message. Then prepare the project again with `--allowRecreate`.
- After prepare, check the `runtime state` of each task. Each task must show `READY_TO_RUN`.
