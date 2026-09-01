import assert from "node:assert/strict";
import test from "node:test";

import {
  DELETE_ACCOUNT_CONFIRMATION,
  RECENT_AUTH_MAX_AGE_SECONDS,
  DeleteAccountValidationError,
  assertRecentAuthentication,
  parseDeleteAccountInput,
} from "../src/delete_account_core";

test(
  "explicit account deletion confirmation is accepted",
  () => {
    assert.deepEqual(
      parseDeleteAccountInput({
        confirmation:
          DELETE_ACCOUNT_CONFIRMATION,
      }),
      {
        confirmation:
          DELETE_ACCOUNT_CONFIRMATION,
      },
    );
  },
);

test(
  "missing account deletion confirmation is rejected",
  () => {
    assert.throws(
      () =>
        parseDeleteAccountInput({}),
      DeleteAccountValidationError,
    );
  },
);

test(
  "incorrect account deletion confirmation is rejected",
  () => {
    assert.throws(
      () =>
        parseDeleteAccountInput({
          confirmation: "delete",
        }),
      DeleteAccountValidationError,
    );
  },
);

test(
  "unknown account deletion fields are rejected",
  () => {
    assert.throws(
      () =>
        parseDeleteAccountInput({
          confirmation:
            DELETE_ACCOUNT_CONFIRMATION,
          unexpected: true,
        }),
      DeleteAccountValidationError,
    );
  },
);

test(
  "non-object account deletion input is rejected",
  () => {
    for (
      const value of [
        null,
        undefined,
        "DELETE_ACCOUNT",
        [],
      ]
    ) {
      assert.throws(
        () =>
          parseDeleteAccountInput(value),
        DeleteAccountValidationError,
      );
    }
  },
);

test(
  "recent authentication is accepted",
  () => {
    const now = 2_000_000;

    assert.doesNotThrow(() =>
      assertRecentAuthentication(
        now - 60,
        now,
      ),
    );

    assert.doesNotThrow(() =>
      assertRecentAuthentication(
        now -
          RECENT_AUTH_MAX_AGE_SECONDS,
        now,
      ),
    );
  },
);

test(
  "authentication older than ten minutes is rejected",
  () => {
    const now = 2_000_000;

    assert.throws(
      () =>
        assertRecentAuthentication(
          now -
            RECENT_AUTH_MAX_AGE_SECONDS -
            1,
          now,
        ),
      (error: unknown) => {
        assert.ok(
          error instanceof
            DeleteAccountValidationError,
        );

        assert.equal(
          error.reason,
          "recent-auth-required",
        );

        return true;
      },
    );
  },
);

test(
  "missing or invalid auth_time is rejected",
  () => {
    const now = 2_000_000;

    for (
      const value of [
        null,
        undefined,
        "",
        0,
        -1,
        Number.NaN,
      ]
    ) {
      assert.throws(
        () =>
          assertRecentAuthentication(
            value,
            now,
          ),
        DeleteAccountValidationError,
      );
    }
  },
);

test(
  "future auth_time is rejected",
  () => {
    const now = 2_000_000;

    assert.throws(
      () =>
        assertRecentAuthentication(
          now + 1,
          now,
        ),
      DeleteAccountValidationError,
    );
  },
);
