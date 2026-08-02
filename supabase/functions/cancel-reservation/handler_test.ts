import {
  cancelReservationHandler,
  isRefundable,
  type CancelReservationDependencies,
} from "./handler.ts";

const reservationId = "22222222-2222-4222-8222-222222222222";
const userId = "44444444-4444-4444-8444-444444444444";
const paymentIntentId = "pi_test_12345678";

function request(body: Record<string, unknown> = {}): Request {
  return new Request("https://functions.example/cancel-reservation", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      reservation_id: reservationId,
      ...body,
    }),
  });
}

function dependencies(
  overrides: Partial<CancelReservationDependencies> = {},
): CancelReservationDependencies {
  const start = new Date(Date.now() + 5 * 60 * 60_000).toISOString();
  return {
    authenticate: async () => ({ id: userId }),
    loadReservation: async () => ({
      id: reservationId,
      driverId: userId,
      status: "confirmed",
      startTime: start,
    }),
    loadSucceededPayment: async () => ({
      id: "33333333-3333-4333-8333-333333333333",
      status: "succeeded",
      stripePaymentIntentId: paymentIntentId,
      stripeRefundId: null,
    }),
    createRefund: async () => ({ id: "re_test_12345678" }),
    applyCancellation: async () => "cancelled",
    now: () => new Date(),
    ...overrides,
  };
}

async function readJson(res: Response): Promise<Record<string, unknown>> {
  return await res.json() as Record<string, unknown>;
}

Deno.test("cancel reservation refunds when more than 2 hours remain", async () => {
  let refundedPi: string | null = null;
  const handler = cancelReservationHandler(dependencies({
    createRefund: async (pi) => {
      refundedPi = pi;
      return { id: "re_test_12345678" };
    },
  }));
  const res = await handler(request());
  const body = await readJson(res);
  if (res.status !== 200) throw new Error(`status ${res.status}`);
  if (body.refunded !== true) throw new Error("expected refunded");
  if (refundedPi !== paymentIntentId) throw new Error("refund PI mismatch");
});

Deno.test("cancel reservation skips refund inside 2 hour window", async () => {
  let createdRefund = false;
  const startSoon = new Date(Date.now() + 30 * 60_000).toISOString();
  const handler = cancelReservationHandler(dependencies({
    loadReservation: async () => ({
      id: reservationId,
      driverId: userId,
      status: "confirmed",
      startTime: startSoon,
    }),
    createRefund: async () => {
      createdRefund = true;
      return { id: "re_should_not_run" };
    },
  }));
  const res = await handler(request());
  const body = await readJson(res);
  if (res.status !== 200) throw new Error(`status ${res.status}`);
  if (body.refunded !== false) throw new Error("expected no refund");
  if (createdRefund) throw new Error("should not call Stripe refund");
});

Deno.test("isRefundable respects two hour lead", () => {
  const now = new Date("2026-07-24T12:00:00Z");
  if (!isRefundable("2026-07-24T15:00:00Z", now)) {
    throw new Error("3h should refund");
  }
  if (isRefundable("2026-07-24T13:30:00Z", now)) {
    throw new Error("1.5h should not refund");
  }
});
