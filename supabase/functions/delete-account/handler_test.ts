import {
  type DeleteAccountDependencies,
  deleteAccountHandler,
  parseAccountDeletionStorageObjects,
} from "./handler.ts";

const userId = "44444444-4444-4444-8444-444444444444";

function request(body: Record<string, unknown>): Request {
  return new Request("https://functions.example/delete-account", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function dependencies(
  overrides: Partial<DeleteAccountDependencies> = {},
): DeleteAccountDependencies {
  return {
    authenticate: async () => ({ id: userId }),
    getStripeCustomerId: async () => null,
    deleteStripeCustomer: async () => {},
    prepareAccountDeletion: async () => [],
    deleteStorageObjects: async () => {},
    deleteAuthUser: async () => {},
    completeAccountDeletion: async () => {},
    ...overrides,
  };
}

Deno.test("delete account never accepts a target user id", async () => {
  let cleanupCalled = false;
  const handler = deleteAccountHandler(
    dependencies({
      prepareAccountDeletion: async () => {
        cleanupCalled = true;
        return [];
      },
    }),
  );
  const response = await handler(
    request({ confirmation: "DELETE", user_id: "attacker-selected-id" }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error_code, "unexpected_field");
  assertEquals(cleanupCalled, false);
});

Deno.test("delete account uses JWT user and cleans data before Auth deletion", async () => {
  const calls: string[] = [];
  const handler = deleteAccountHandler(
    dependencies({
      prepareAccountDeletion: async (id) => {
        calls.push(`cleanup:${id}`);
        return [{ bucketId: "avatars", name: `${id}/avatar.jpg` }];
      },
      getStripeCustomerId: async () => "cus_test_123",
      deleteStripeCustomer: async () => {
        calls.push("stripe");
      },
      deleteStorageObjects: async (objects) => {
        calls.push(`storage:${objects.length}`);
      },
      deleteAuthUser: async (id) => {
        calls.push(`auth:${id}`);
      },
      completeAccountDeletion: async (id) => {
        calls.push(`complete:${id}`);
      },
    }),
  );
  const response = await handler(request({ confirmation: "DELETE" }));
  assertEquals(response.status, 200);
  assertEquals(
    calls.join(","),
    `stripe,cleanup:${userId},storage:1,auth:${userId},complete:${userId}`,
  );
});

Deno.test("failed completion remains eligible for scheduled reconciliation", async () => {
  let completionCalled = false;
  const handler = deleteAccountHandler(
    dependencies({
      completeAccountDeletion: async () => {
        completionCalled = true;
        throw new Error("database unavailable");
      },
    }),
  );
  const response = await handler(request({ confirmation: "DELETE" }));
  assertEquals(response.status, 500);
  assertEquals(completionCalled, true);
  assertEquals(JSON.stringify(await response.json()).includes("database unavailable"), false);
});

Deno.test("failed cleanup does not delete the Auth user", async () => {
  let authDeleted = false;
  const handler = deleteAccountHandler(
    dependencies({
      prepareAccountDeletion: async () => {
        throw new Error("database unavailable");
      },
      deleteAuthUser: async () => {
        authDeleted = true;
      },
    }),
  );
  const response = await handler(request({ confirmation: "DELETE" }));
  assertEquals(response.status, 500);
  assertEquals(authDeleted, false);
  assertEquals(JSON.stringify(await response.json()).includes("database unavailable"), false);
});

Deno.test("account cleanup storage snapshot rejects unexpected buckets and paths", () => {
  assertThrows(() =>
    parseAccountDeletionStorageObjects(
      [{ bucket_id: "private-documents", name: `${userId}/secret.pdf` }],
      userId,
    )
  );
  assertThrows(() =>
    parseAccountDeletionStorageObjects(
      [{ bucket_id: "avatars", name: "another-user/avatar.jpg" }],
      userId,
    )
  );
  assertEquals(
    parseAccountDeletionStorageObjects(
      [{ bucket_id: "avatars", name: `${userId}/avatar.jpg` }],
      userId,
    ).length,
    1,
  );
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertThrows(action: () => unknown): void {
  try {
    action();
  } catch {
    return;
  }
  throw new Error("Expected action to throw.");
}
