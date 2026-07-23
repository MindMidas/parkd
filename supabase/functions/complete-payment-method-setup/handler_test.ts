import { completePaymentMethodSetupHandler, type CompleteSetupDependencies } from "./handler.ts";

const userId = "44444444-4444-4444-8444-444444444444";

function request(): Request {
  return new Request("https://functions.example/complete-payment-method-setup", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer token" },
    body: JSON.stringify({ setup_intent_id: "seti_test_12345678" }),
  });
}

function dependencies(
  overrides: Partial<CompleteSetupDependencies> = {},
): CompleteSetupDependencies {
  return {
    authenticate: async () => ({ id: userId }),
    retrieveSetupIntent: async () => ({
      id: "seti_test_12345678",
      status: "succeeded",
      livemode: false,
      userId,
      application: "parkd",
      customerId: "cus_test_123",
      paymentMethodId: "pm_test_123",
    }),
    retrieveCard: async () => ({
      paymentMethodId: "pm_test_123",
      livemode: false,
      brand: "Visa",
      last4: "4242",
      expMonth: 12,
      expYear: 2035,
    }),
    getOrCreateCustomer: async () => "cus_test_123",
    ensurePaymentMethodOnCustomer: async () => {},
    savePaymentMethod: async () => "55555555-5555-4555-8555-555555555555",
    ...overrides,
  };
}

Deno.test("card setup cannot be completed by a different user", async () => {
  let saved = false;
  const handler = completePaymentMethodSetupHandler(
    dependencies({
      retrieveSetupIntent: async () => ({
        id: "seti_test_12345678",
        status: "succeeded",
        livemode: false,
        userId: "66666666-6666-4666-8666-666666666666",
        application: "parkd",
        customerId: "cus_test_123",
        paymentMethodId: "pm_test_123",
      }),
      savePaymentMethod: async () => {
        saved = true;
        return "unreachable";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 403);
  assertEquals(saved, false);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
