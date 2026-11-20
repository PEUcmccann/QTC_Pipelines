# BOM landing in slices (DEV and PROD)

The BOM view loads in 11 slices, in DEV and in PROD. This note explains why, and how to keep the slices correct.

In PROD, consumers read the dynamic table `PROD_STAGING.SAP.BILLOFMATERIALS`. In DEV, they read the older view `DEV_RAW.SAP.BILLOFMATERIALS`.

## Why slices

HANA times out when one task reads the whole view `_SYS_BIC."jbs_bw4_hana.edw.plm.bom/C_BOMITEMVALIDMATERIALSEXPLOSION"`. Each slice reads a part of the view, so each query finishes in about 2 minutes.

## What was built in DEV

- Project: `SAP_BW_BILLOFMATERIALS_SLICED` (ID `6b001cac615236a2d9dcb200`), DEV space.
- Source connection: `DEV_SRC_SAP_HBP_BW`. Target connection: `DEV_TGT_SNOWFLAKE_DEV_RAW`. Target schema: `SAP`.
- 11 replication tasks, full load only. Each task writes `BILLOFMATERIALS_<nn>`.
- View `DEV_RAW.SAP.BILLOFMATERIALS` combines the 11 tables with `UNION ALL BY NAME`.
- The DEV view was built before the staging pattern below. It does not follow that pattern. Unknown: whether DEV will move to `DEV_STAGING`.
- Columns: the 29 columns of the Qlik Sense statement. The view also has `C_BOMLEVEL` and two `*SCRAPINPERCENT` columns. The tasks drop them.

## Slice rules

The slices do not overlap. Together they equal `PLANT IN (96 plants)` from the Qlik Sense statement.

| Slice | Filter | Rows (2026-11-20) |
| --- | --- | --- |
| 01-06 | Plant `2500`, split by `BILLOFMATERIAL` range | about 212,000 each |
| 07-09 | Plant `PF69`, split by `BILLOFMATERIAL` range | about 169,000 each |
| 10 | Plants `FR90`, `FR91`, `FR92` | 285,695 |
| 11 | The other plants in the list of 96 | 459,000 |

The range limits are in each task dataset, in `transformations.filter`. Slice 11 also catches any plant that is in the list of 96 but not in slices 01-10.

## Keep it correct

- Run all 11 tasks to refresh. Each task truncates its table first. Do not query the view during a refresh.
- Check for skew after a refresh. If one slice has more than 500,000 rows, move its range limits.
- The first limit was 400,000. Slice 11 has about 459,000 rows and does not time out. So the limit is now 500,000.
- The `PLANT NOT IN (...)` list in the Qlik Sense statement has 818 plants. None of them is in the include list. The slices do not use it.
- A QVD built before the load has fewer rows if SAP changed after the QVD was built. On 2026-11-20 the load had 32 more rows than the QVD, all in plant `PF56`.

## Check query

```sql
SELECT PLANT, COUNT(*) AS n FROM DEV_RAW.SAP.BILLOFMATERIALS GROUP BY PLANT ORDER BY n DESC;
```

## Open items

- No schedule is set in DEV or PROD. Ask before you enable one.
- The first project `SAP_BW_BILLOFMATERIALS` (ID `6b001421443ce800a27244a9`) is unused. The API cannot delete it. Delete it in the Qlik Cloud UI.

## PROD

### Steps to build PROD from the DEV export

1. Copy the DEV export folder.
2. In `bindings.json`, change the source to `PROD.PROD_SRC_SAP_HBP_BW`.
3. In `bindings.json`, change the target to `PROD.PROD_TGT_SNOWFLAKE_PROD_RAW`.
4. Write `vars.json` with the PROD connection IDs in `nameToIdMap`.
5. Create the project in the PROD space. Then pack, import, validate and prepare. See `docs/qtc-import.md`.
6. Run the smallest slice first. Then run the other 10.
7. Run `sql/prod/billofmaterials_dynamic_table.sql` as `ENGINEER_ROLE`.
8. Run `sql/prod/billofmaterials_reconciliation.sql`.
9. Compare the per-plant counts with the QVD by hand. The QVD is not in Snowflake. Use `docs/qvds/masterdata/bill_of_materials.csv`.
10. Export the project into a new folder `<PROJECT>_<timestamp>_ALL`.

### What was built in PROD

- Project: `SAP_BW_BILLOFMATERIALS_SLICED` (ID `6b004ecf615236a2d9dcb2c3`), PROD space. Source connection: `PROD_SRC_SAP_HBP_BW`. Target connection: `PROD_TGT_SNOWFLAKE_PROD_RAW`. Target schema: `SAP`.
- The slice ranges are the DEV ranges. All 11 tasks ran once on 2026-11-20 in about 2 minutes. HANA did not time out.
- The slices land in `PROD_RAW.SAP.BILLOFMATERIALS_01` to `_11`. The combined object is the dynamic table `PROD_STAGING.SAP.BILLOFMATERIALS`. On 2026-11-20 it had 2,528,670 rows.
- The dynamic table uses `STAGING_WH`, `TARGET_LAG` 24 hours and owner `ENGINEER_ROLE`. The DDL is in `sql/prod/billofmaterials_dynamic_table.sql`.
- The reconciliation query is `sql/prod/billofmaterials_reconciliation.sql`. Run it after each full reload.
- On 2026-11-20 slice 11 had 459,556 rows. This is below the 500,000 limit.
- On 2026-11-20 PROD had small count differences from DEV in 4 plants (PF57, 2501, PF56, 2503). The cause is Unknown.
- `PROD_RAW.SAP.BOM` is an empty table that is not part of this build. Do not use it.
- The export is in the folder `SAP_BW_BILLOFMATERIALS_SLICED_2026-11-20T14_02_42.117Z_ALL`. It is the PROD project. The DEV export has an earlier timestamp.

## Where sliced data comes together

Use this pattern for every sliced view.

1. The slice tasks write the slice tables to the raw database. QTC writes only to the raw database.
2. One combined object combines the slice tables with `UNION ALL BY NAME`. It lives in the staging database, in the schema that matches the raw schema.
3. The combined object is a dynamic table, not a view. A view shows partial data while a slice truncates its table.
4. Consumers read the combined object only. They never read the slice tables.

Open risk: the dynamic table refreshes every 24 hours, whatever the slice schedule. If a slice reload is running at refresh time, the table holds partial data until the next refresh. When you set a schedule, finish the 11 slices well before the refresh time. A task that gates the refresh on all slices is not built.