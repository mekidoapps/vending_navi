/**
 * RETIRED.
 *
 * The production audit proved that a missing legacy status cannot safely be
 * interpreted as `active`, and that `available` has no documented
 * vending-machine status meaning in the v1 source. Keep this command as an
 * explicit failure so an old runbook cannot accidentally mutate production.
 */
throw new Error(
  "Retired unsafe backfill. Use npm run plan:legacy-migration for a read-only " +
    "classification; production writes require an approved Phase B plan.",
);
