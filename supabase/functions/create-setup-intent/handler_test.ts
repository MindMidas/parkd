import { type CreateSetupDependencies, createSetupIntentHandler } from "./handler.ts";

const userId = "44444444-4444-4444-8444-444444444444";

function request(body: Record<string, unknown>): Request {
  return new Request("https://functions.example/create-setup-intent", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer token" },
    body: JSON.stringify(body),
  });
}

Deno.test("setup intent uses caller and retry key in Stripe idempotency key", async () => {
  let received = "";
  const dependencies: CreateSetupDependencies = {
    authenticate: async () => ({ id: userId }),
    getOrCreateCustomer: async () => "cus_test_123",
    createSetupIntent: async (input) => {
      received = input.idempotencyKey;
      return {
        id: "seti_test_12345678",
        clientSecret: "seti_test_secret",
        livemode: false,
      };
    },
  };
  const response = await createSetupIntentHandler(dependencies)(
    request({ idempotency_key: "setup_attempt_00000001" }),
  );
  assertEquals(response.status, 200);
  assertEquals(
    received,
    `parkd-demo:setup:${userId}:setup_attempt_00000001`,
  );
});

Deno.test("setup intent rejects live Stripe response", async () => {
  const dependencies: CreateSetupDependencies = {
    authenticate: async () => ({ id: userId }),
    getOrCreateCustomer: async () => "cus_test_123",
    createSetupIntent: async () => ({
      id: "seti_live_12345678",
      clientSecret: "secret",
      livemode: true,
    }),
  };
  const response = await createSetupIntentHandler(dependencies)(
    request({ idempotency_key: "setup_attempt_00000001" }),
  );
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error_code, "live_object_rejected");
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
