import {
  assertServiceRoleAuthorization,
  type CleanupCandidate,
  type CleanupDependencies,
  purgeExpiredDemoDataHandler,
} from "./handler.ts";

const userId = "77777777-7777-4777-8777-777777777777";
const candidate: CleanupCandidate = {
  userId,
  stripeCustomerId: "cus_demo_123",
  storageObjects: [{ bucketId: "avatars", name: `${userId}/avatar.jpg` }],
  prepared: false,
  attemptCount: 1,
};

function request(
  body: Record<string, unknown> = {},
  options: { token?: string; method?: string; origin?: string } = {},
): Request {
  const headers: Record<string, string> = {
    authorization: `Bearer ${options.token ?? "service-secret"}`,
    "content-type": "application/json",
  };
  if (options.origin) headers.origin = options.origin;
  return new Request("https://functions.example/purge-expired-demo-data", {
    method: options.method ?? "POST",
    headers,
    body: options.method === "GET" ? undefined : JSON.stringify(body),
  });
}

function dependencies(
  overrides: Partial<CleanupDependencies> = {},
): CleanupDependencies {
  return {
    authorize: (req) => assertServiceRoleAuthorization(req, "service-secret"),
    advanceReservationLifecycle: async () => {},
    claimCandidates: async () => [],
    deleteStripeCustomer: async () => {},
    prepareAccountDeletion: async () => [],
    deleteStorageObjects: async () => {},
    deleteAuthUser: async () => {},
    completeAccountDeletion: async () => {},
    recordFailure: async () => {},
    ...overrides,
  };
}

Deno.test("cleanup endpoint requires the exact service-role bearer token", async () => {
  let claimed = false;
  const handler = purgeExpiredDemoDataHandler(
    dependencies({
      claimCandidates: async () => {
        claimed = true;
        return [];
      },
    }),
  );
  const response = await handler(request({}, { token: "wrong-secret" }));
  assertEquals(response.status, 401);
  assertEquals((await response.json()).error_code, "unauthorized");
  assertEquals(claimed, false);
});

Deno.test("cleanup endpoint rejects browsers and invalid batch limits", async () => {
  const handler = purgeExpiredDemoDataHandler(dependencies());
  const browserResponse = await handler(request({}, { origin: "https://portfolio.example" }));
  assertEquals(browserResponse.status, 403);

  const invalidLimitResponse = await handler(request({ limit: 101 }));
  assertEquals(invalidLimitResponse.status, 400);
  assertEquals((await invalidLimitResponse.json()).error_code, "invalid_limit");
});

Deno.test("cleanup batch executes resumable external deletion in order", async () => {
  const calls: string[] = [];
  const handler = purgeExpiredDemoDataHandler(
    dependencies({
      advanceReservationLifecycle: async () => {
        calls.push("lifecycle");
      },
      claimCandidates: async (limit) => {
        calls.push(`claim:${limit}`);
        return [candidate];
      },
      deleteStripeCustomer: async (id) => {
        calls.push(`stripe:${id}`);
      },
      prepareAccountDeletion: async (id) => {
        calls.push(`prepare:${id}`);
        return [{ bucketId: "listing-photos", name: `${id}/listing/photo.jpg` }];
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

  const response = await handler(request({ limit: 7 }));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).completed, 1);
  assertEquals(
    calls.join(","),
    `lifecycle,claim:7,stripe:cus_demo_123,prepare:${userId},storage:2,auth:${userId},complete:${userId}`,
  );
});

Deno.test("a partial failure is recorded and other candidates still complete", async () => {
  const secondUser = "88888888-8888-4888-8888-888888888888";
  const failures: string[] = [];
  const completed: string[] = [];
  const handler = purgeExpiredDemoDataHandler(
    dependencies({
      claimCandidates: async () => [
        candidate,
        {
          ...candidate,
          userId: secondUser,
          stripeCustomerId: null,
          storageObjects: [],
        },
      ],
      deleteStripeCustomer: async () => {
        throw new Error("Stripe is unavailable and this must not leak");
      },
      prepareAccountDeletion: async () => [],
      completeAccountDeletion: async (id) => {
        completed.push(id);
      },
      recordFailure: async (id, code) => {
        failures.push(`${id}:${code}`);
      },
    }),
  );

  const response = await handler(request());
  const body = await response.json();
  assertEquals(response.status, 500);
  assertEquals(body.completed, 1);
  assertEquals(body.failed, 1);
  assertEquals(JSON.stringify(body).includes("Stripe is unavailable"), false);
  assertEquals(failures.join(","), `${userId}:stripe_failed`);
  assertEquals(completed.join(","), secondUser);
});

Deno.test("invalid candidate paths fail closed and release the lease", async () => {
  const failures: string[] = [];
  const handler = purgeExpiredDemoDataHandler(
    dependencies({
      claimCandidates: async () => [{
        ...candidate,
        storageObjects: [{ bucketId: "avatars", name: "another-user/avatar.jpg" }],
      }],
      recordFailure: async (id, code) => {
        failures.push(`${id}:${code}`);
      },
    }),
  );

  const response = await handler(request());
  assertEquals(response.status, 500);
  assertEquals(failures.join(","), `${userId}:candidate_failed`);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
