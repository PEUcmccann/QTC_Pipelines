# BOM landing in slices (DEV and PROD)

This note explains why `DEV_RAW.SAP.BILLOFMATERIALS` is a view over 11 slice tables. It also explains how to keep the slices correct.

## Why slices

HANA times out when one task reads the whole view `_SYS_BIC."jbs_bw4_hana.edw.plm.bom/C_BOMITEMVALIDMATERIALSEXPLOSION"`. Each slice reads a part of the view, so each query finishes in about 2 minutes.

## What was built

- Project: `SAP_BW_BILLOFMATERIALS_SLICED` (ID `6b001cac615236a2d9dcb200`), DEV space.
- Source connection: `DEV_SRC_SAP_HBP_BW`. Target connection: `DEV_TGT_SNOWFLAKE_DEV_RAW`. Target schema: `SAP`.
- 11 replication tasks, full load only. Each task writes `BILLOFMATERIALS_<nn>`.
- View `DEV_RAW.SAP.BILLOFMATERIALS` joins the 11 tables with `UNION ALL BY NAME`.
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
- Check for skew after a refresh. If one slice has more than 400,000 rows, move its range limits.
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

- Project: `SAP_BW_BILLOFMATERIALS_SLICED` (ID `6b004ecf615236a2d9dcb2c3`), PROD space. Source connection: `PROD_SRC_SAP_HBP_BW`. Target connection: `PROD_TGT_SNOWFLAKE_PROD_RAW`. Target schema: `SAP`.
- The slice ranges are the DEV ranges. All 11 tasks ran once on 2026-11-20 in about 2 minutes. HANA did not time out.
- The slices land in `PROD_RAW.SAP.BILLOFMATERIALS_01` to `_11`. The combined object is the dynamic table `PROD_STAGING.SAP.BILLOFMATERIALS`. It has 2,528,670 rows.
- The dynamic table uses `STAGING_WH`, `TARGET_LAG` 24 hours and owner `ENGINEER_ROLE`. The DDL is in `sql/prod/billofmaterials_dynamic_table.sql`.
- The reconciliation query is `sql/prod/billofmaterials_reconciliation.sql`. Run it after each full reload.
- Slice 11 has 459,556 rows, above the first limit of 400,000. It does not time out, so the limit is now 500,000.
- On 2026-11-20 PROD had small count differences from DEV in 4 plants (PF57, 2501, PF56, 2503). The cause is Unknown.
- `PROD_RAW.SAP.BOM` is an empty table that is not part of this build. Do not use it.
- The export is in the folder `SAP_BW_BILLOFMATERIALS_SLICED_2026-11-20T14_02_42.117Z_ALL`. It is the PROD project. The DEV export has an earlier timestamp.

## Where sliced data comes together

Use this pattern for every sliced view.

1. The slice tasks write the slice tables to the raw database. QTC writes only to the raw database.
2. One combined object joins the slice tables. It lives in the staging database, in the schema that matches the raw schema.
3. The combined object is a dynamic table, not a view. A view shows partial data while a slice truncates its table.
4. Consumers read the combined object only. They never read the slice tables.

Open risk: the dynamic table refreshes every 24 hours, whatever the slice schedule. If a slice reload is running at refresh time, the table holds partial data until the next refresh. When you set a schedule, finish the 11 slices well before the refresh time. A task that gates the refresh on all slices is not built.