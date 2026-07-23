import {
  type CheckoutDependencies,
  createPaymentIntentHandler,
  type PreparedCheckout,
} from "./handler.ts";

const listingId = "11111111-1111-4111-8111-111111111111";
const reservationId = "22222222-2222-4222-8222-222222222222";
const paymentId = "33333333-3333-4333-8333-333333333333";
const userId = "44444444-4444-4444-8444-444444444444";
const idempotencyKey = "checkout_attempt_00000001";

function prepared(overrides: Partial<PreparedCheckout> = {}): PreparedCheckout {
  return {
    reservationId,
    paymentId,
    subtotalCents: 1000,
    serviceFeeCents: 150,
    amountCents: 1150,
    currency: "cad",
    stripePaymentIntentId: null,
    stripeCheckoutSessionId: null,
    stripePaymentMethodId: null,
    ...overrides,
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("https://functions.example/create-payment-intent", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      listing_id: listingId,
      start_time: new Date(Date.now() + 60 * 60_000).toISOString(),
      end_time: new Date(Date.now() + 2 * 60 * 60_000).toISOString(),
      idempotency_key: idempotencyKey,
      ...body,
    }),
  });
}

function dependencies(
  overrides: Partial<CheckoutDependencies> = {},
): CheckoutDependencies {
  return {
    authenticate: async () => ({ id: userId }),
    prepareCheckout: async () => prepared(),
    getOrCreateCustomer: async () => "cus_test_customer",
    ensurePaymentMethodOnCustomer: async () => {},
    retrievePaymentIntent: async () => paymentIntent(),
    createPaymentIntent: async () => paymentIntent(),
    recordPaymentIntent: async () => {},
    retrieveCheckoutSession: async () => checkoutSession(),
    createCheckoutSession: async () => checkoutSession(),
    recordCheckoutSession: async () => {},
    maxPaymentCents: 50_000,
    ...overrides,
  };
}

function paymentIntent(overrides: Record<string, unknown> = {}) {
  return {
    id: "pi_test_12345678",
    clientSecret: "test-client-secret",
    status: "requires_payment_method",
    livemode: false,
    amount: 1150,
    currency: "cad",
    paymentMethodId: null,
    metadata: {
      payment_id: paymentId,
      reservation_id: reservationId,
      application: "parkd",
    },
    ...overrides,
  };
}

function checkoutSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "cs_test_12345678",
    url: "https://checkout.stripe.test/session",
    livemode: false,
    amountTotal: 1150,
    currency: "cad",
    paymentIntentId: null,
    metadata: {
      payment_id: paymentId,
      reservation_id: reservationId,
      application: "parkd",
    },
    status: "open",
    ...overrides,
  };
}

Deno.test("checkout rejects client-supplied prices", async () => {
  let preparedCalled = false;
  const handler = createPaymentIntentHandler(
    dependencies({
      prepareCheckout: async () => {
        preparedCalled = true;
        return prepared();
      },
    }),
  );
  const response = await handler(request({ amount_cents: 1 }));
  assertEquals(response.status, 400);
  assertEquals(preparedCalled, false);
  assertEquals((await response.json()).error_code, "unexpected_field");
});

Deno.test("mobile checkout sends only trusted RPC amount to Stripe", async () => {
  let stripeAmount = 0;
  let stripeIdempotency = "";
  let recorded = "";
  const handler = createPaymentIntentHandler(
    dependencies({
      createPaymentIntent: async (input) => {
        stripeAmount = input.amount;
        stripeIdempotency = input.idempotencyKey;
        return paymentIntent();
      },
      recordPaymentIntent: async (_, intentId) => {
        recorded = intentId;
      },
    }),
  );

  const response = await handler(request({ platform: "mobile" }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(stripeAmount, 1150);
  assertEquals(stripeIdempotency, `parkd:payment:${paymentId}:v1`);
  assertEquals(recorded, "pi_test_12345678");
  assertEquals(body.subtotal_cents, 1000);
  assertEquals(body.service_fee_cents, 150);
  assertEquals(body.amount_cents, 1150);
});

Deno.test("existing payment intent is reused instead of duplicated", async () => {
  let createCalls = 0;
  const handler = createPaymentIntentHandler(
    dependencies({
      prepareCheckout: async () => prepared({ stripePaymentIntentId: "pi_test_existing123" }),
      retrievePaymentIntent: async () => paymentIntent({ id: "pi_test_existing123" }),
      createPaymentIntent: async () => {
        createCalls++;
        return paymentIntent();
      },
    }),
  );
  const response = await handler(request({}));
  assertEquals(response.status, 200);
  assertEquals(createCalls, 0);
});

Deno.test("web checkout rejects redirect origins outside CORS allowlist", async () => {
  const handler = createPaymentIntentHandler(dependencies());
  const response = await handler(
    request({
      platform: "web",
      success_url: "https://evil.example/success",
      cancel_url: "https://evil.example/cancel",
    }),
  );
  assertEquals(response.status, 400);
  assertEquals((await response.json()).error_code, "invalid_redirect");
});

Deno.test("web checkout uses trusted amount and returns Stripe-hosted URL", async () => {
  let createdAmount = 0;
  let sessionKey = "";
  const handler = createPaymentIntentHandler(
    dependencies({
      createCheckoutSession: async (input) => {
        createdAmount = input.amount;
        sessionKey = input.idempotencyKey;
        return checkoutSession();
      },
    }),
  );
  const response = await handler(
    request({
      platform: "web",
      success_url: "http://localhost:3000/payment/success",
      cancel_url: "http://localhost:3000/payment/cancel",
    }),
  );
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(createdAmount, 1150);
  assertEquals(sessionKey, `parkd:checkout-session:${paymentId}:v1`);
  assertEquals(body.checkout_url, "https://checkout.stripe.test/session");
});

Deno.test("live Stripe objects are accepted", async () => {
  const handler = createPaymentIntentHandler(
    dependencies({
      createPaymentIntent: async () => paymentIntent({ livemode: true }),
    }),
  );
  const response = await handler(request({}));
  assertEquals(response.status, 200);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
