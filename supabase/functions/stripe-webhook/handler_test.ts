import {
  stripeWebhookHandler,
  type VerifiedWebhookEvent,
  type WebhookDependencies,
} from "./handler.ts";

const paymentId = "33333333-3333-4333-8333-333333333333";
const reservationId = "22222222-2222-4222-8222-222222222222";

function request(signature = "t=1,v1=test"): Request {
  return new Request("https://functions.example/stripe-webhook", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "stripe-signature": signature,
    },
    body: JSON.stringify({ test: true }),
  });
}

function paymentEvent(
  overrides: Partial<VerifiedWebhookEvent> = {},
): VerifiedWebhookEvent {
  return {
    id: "evt_test_12345678",
    type: "payment_intent.succeeded",
    livemode: false,
    created: Math.floor(Date.now() / 1000),
    paymentIntent: {
      id: "pi_test_12345678",
      livemode: false,
      amount: 1150,
      amountReceived: 1150,
      currency: "cad",
      metadata: {
        payment_id: paymentId,
        reservation_id: reservationId,
        application: "parkd",
      },
    },
    checkoutSession: null,
    ...overrides,
  };
}

function dependencies(
  overrides: Partial<WebhookDependencies> = {},
): WebhookDependencies {
  return {
    verifyEvent: async () => paymentEvent(),
    processEvent: async () => "processed",
    ...overrides,
  };
}

Deno.test("webhook rejects an invalid Stripe signature", async () => {
  let processed = false;
  const handler = stripeWebhookHandler(
    dependencies({
      verifyEvent: async () => {
        throw new Error("signature mismatch with secret material");
      },
      processEvent: async () => {
        processed = true;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  const body = await response.json();
  assertEquals(response.status, 400);
  assertEquals(body.error_code, "invalid_signature");
  assertEquals(processed, false);
  assertEquals(JSON.stringify(body).includes("secret material"), false);
});

Deno.test("webhook accepts live-mode events", async () => {
  const event = paymentEvent({ livemode: true });
  event.paymentIntent!.livemode = true;
  const handler = stripeWebhookHandler(dependencies({ verifyEvent: async () => event }));
  const response = await handler(request());
  assertEquals(response.status, 200);
});

Deno.test("payment webhook passes verified trusted data to atomic processor", async () => {
  let received: Record<string, unknown> = {};
  const handler = stripeWebhookHandler(
    dependencies({
      processEvent: async (input) => {
        received = input as unknown as Record<string, unknown>;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertEquals(received.paymentIntentId, "pi_test_12345678");
  assertEquals(received.paymentId, paymentId);
  assertEquals(received.reservationId, reservationId);
  assertEquals(received.amountCents, 1150);
  assertEquals(received.livemode, false);
});

Deno.test("duplicate event receipt is acknowledged without failure", async () => {
  const handler = stripeWebhookHandler(
    dependencies({ processEvent: async () => "duplicate" }),
  );
  const response = await handler(request());
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.outcome, "duplicate");
});

Deno.test("paid Checkout Session finalizes through its PaymentIntent", async () => {
  let checkoutSessionId: unknown;
  const event = paymentEvent({
    type: "checkout.session.completed",
    paymentIntent: null,
    checkoutSession: {
      id: "cs_test_12345678",
      livemode: false,
      paymentStatus: "paid",
      paymentIntentId: "pi_test_12345678",
      amountTotal: 1150,
      currency: "cad",
      metadata: {
        payment_id: paymentId,
        reservation_id: reservationId,
        application: "parkd",
      },
    },
  });
  const handler = stripeWebhookHandler(
    dependencies({
      verifyEvent: async () => event,
      processEvent: async (input) => {
        checkoutSessionId = input.checkoutSessionId;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertEquals(checkoutSessionId, "cs_test_12345678");
});

Deno.test("unrelated Stripe objects are ignored", async () => {
  let processed = false;
  const unrelated = paymentEvent();
  unrelated.paymentIntent!.metadata.application = "another_app";
  const handler = stripeWebhookHandler(
    dependencies({
      verifyEvent: async () => unrelated,
      processEvent: async () => {
        processed = true;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertEquals(processed, false);
  assertEquals((await response.json()).outcome, "ignored");
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
