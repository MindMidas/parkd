import { type FinalizeDependencies, finalizeReservationPaymentHandler } from "./handler.ts";

const userId = "44444444-4444-4444-8444-444444444444";
const paymentId = "33333333-3333-4333-8333-333333333333";
const reservationId = "22222222-2222-4222-8222-222222222222";

function request(): Request {
  return new Request("https://functions.example/finalize-reservation-payment", {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer token" },
    body: JSON.stringify({ payment_intent_id: "pi_test_12345678" }),
  });
}

function dependencies(
  overrides: Partial<FinalizeDependencies> = {},
): FinalizeDependencies {
  return {
    authenticate: async () => ({ id: userId }),
    retrievePaymentIntent: async () => ({
      id: "pi_test_12345678",
      status: "succeeded",
      livemode: false,
      amountReceived: 1150,
      currency: "cad",
      metadata: {
        payment_id: paymentId,
        reservation_id: reservationId,
        environment: "portfolio_demo",
      },
    }),
    finalizeVerifiedPayment: async () => "processed",
    ...overrides,
  };
}

Deno.test("finalize fallback uses Stripe-verified amount and JWT user", async () => {
  let received: Record<string, unknown> = {};
  const handler = finalizeReservationPaymentHandler(
    dependencies({
      finalizeVerifiedPayment: async (input) => {
        received = input as unknown as Record<string, unknown>;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 200);
  assertEquals(received.userId, userId);
  assertEquals(received.amountCents, 1150);
  assertEquals(received.paymentId, paymentId);
});

Deno.test("finalize fallback refuses incomplete payment", async () => {
  let finalized = false;
  const handler = finalizeReservationPaymentHandler(
    dependencies({
      retrievePaymentIntent: async () => ({
        id: "pi_test_12345678",
        status: "processing",
        livemode: false,
        amountReceived: 0,
        currency: "cad",
        metadata: {},
      }),
      finalizeVerifiedPayment: async () => {
        finalized = true;
        return "processed";
      },
    }),
  );
  const response = await handler(request());
  assertEquals(response.status, 409);
  assertEquals(finalized, false);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
