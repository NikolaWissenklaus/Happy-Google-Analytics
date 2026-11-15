<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# contributing

Small rules so the project stays readable when more people touch it.

## adding a model

1. Pick the layer by what it reads: staging reads sources, intermediate reads staging, marts read
   core. A mart reading staging directly is a smell (it skips the fixes of the middle layers).
2. File name = table name. Prefix of the area (`mkt_`, `ecom_`, `prod_`... see `docs/architecture.md`).
3. Config block with `description` (what it answers, in one or two sentences, for a human),
   `columns` for anything not obvious, `labels`, `tags` with the area and the schedule.
4. Business rules go to `includes/cfg_*.js`, never inside the SQL.
5. Incremental only when the table is big and partitioned by date. Use
   `helpers.incrementalPreOps` / `incrementalPostOps` and list the `upstream` incrementals, so
   backfills propagate.
6. Optional sources (`enable_*`): `disabled:` in the config and JS ternaries around the joins.
   Compile with everything off and everything on.
7. Personal data: if the table has `user_pseudo_id`, `user_id`, `user_key` or `session_key`, it is
   user level. Put it in a dataset classified as personal data in `cfg_privacy.dataset_classification`
   (`priv_data_inventory` will complain otherwise). Activation tables must join
   `act_consent_eligible_users` and be listed in `priv_activation_consent_audit`.

## SQL style

- CTEs with names that say what they do (`remove_duplicates`, `last_click_before`). If a CTE needs
  a comment to be understood, rename it.
- `GROUP BY` positions are fine, but never on a literal column (BigQuery refuses, the lint catches it).
- `SAFE_DIVIDE` always, `COALESCE` the flags before `NOT`.
- No correlated subqueries with ranges on big tables, join and aggregate instead.
- Dates with the property timezone: `helpers.today()`, `helpers.daysAgo(n)`.
- Comments explain WHY, not what. "GA4 rewrites shards up to 72h later" is a good comment.

## before the PR

```
cd tools
npm run check        # UDF tests + compile + sqlglot validation of every statement
npm run catalog      # refresh docs/catalog.md if you added / renamed models
```

CI runs the same check with every optional module on.
