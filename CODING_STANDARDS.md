# Coding standards

These rules need judgement, so the reviewer applies them to each diff. Mechanical rules run in `scripts/check.ps1`.

## QTC exports and projects

1. **One environment per export, named in the docs.** Export folders differ only by timestamp. Each doc that names an export says if it is DEV or PROD.
2. **DEV and PROD exports differ only in bindings.** Compare them and ignore line endings. Any other difference needs a reason in the pull request.
3. **Slice rules live in one place.** The slice table in `docs/bom-slicing.md` holds the ranges, limits and row counts. Other files point to it. They do not copy the numbers.

## Snowflake SQL in `sql/`

4. **DDL can run again.** Start with `USE ROLE` for the owning role. Use `CREATE OR REPLACE` with `COPY GRANTS`.
5. **Sliced data follows the staging pattern** in `docs/bom-slicing.md`. Each exception has a sentence that says why.
6. **Reconciliation results are clear.** Each check is one row with an actual value, an expected value and `PASS`, `FAIL` or `REVIEW`. A check that reads another environment says so in the file header.
7. **Pin the shape you promise.** If the spec gives a column count or a key, a check asserts it.

## Text in docs, commits, issues and pull requests

8. **Start with context.** The first one or two sentences say what this is and why it exists.
9. **Use ASD-STE100 Simplified Technical English.** Use active voice and common words. Put one idea in each sentence. The check enforces 20 words or fewer.
10. **Keep only what the reader needs** to act or decide.
11. **Read it once as a new reader.** If it is not clear on one read, write it again.
12. **Write "Unknown" for an unknown fact.** Do not add a guess about an owner, a date, a cause or a definition.
13. **Give each count a date.** Write "On 2026-11-20 it had 2,528,670 rows", not "It has 2,528,670 rows".
14. **Use the terms in `GLOSSARY.md`.** For example, write "combines", not "joins", for a combined object.
15. **Change the docs with the behaviour.** A change to a limit, connection or schedule updates each doc that states it.

## Specs and pull requests

16. **Record each spec change on the spec issue.** Also state it in the pull request body.
17. **Use one type for each pull request.** Put an unrelated fix in a new pull request.
