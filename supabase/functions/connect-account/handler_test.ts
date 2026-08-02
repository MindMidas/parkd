import {
  type ConnectDependencies,
  connectAccountHandler,
  type ConnectProfileState,
} from "./handler.ts";

const userId = "44444444-4444-4444-8444-444444444444";

function state(overrides: Partial<ConnectProfileState> = {}): ConnectProfileState {
  return {
    accountId: null,
    chargesEnabled: false,
    detailsSubmitted: false,
    ...overrides,
  };
}

function request(body: Record<string, unknown>): Request {
  return new Request("https://functions.example/connect-account", {
    method: "POST",
    headers: {
      authorization: "Bearer test-token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

function dependencies(
  overrides: Partial<ConnectDependencies> = {},
): ConnectDependencies {
  return {
    authenticate: async () => ({ id: userId, email: "host@example.com" }),
    loadProfileState: async () => state(),
    createExpressAccount: async () => ({
      id: "acct_test123456",
      chargesEnabled: false,
      detailsSubmitted: false,
      livemode: false,
    }),
    retrieveAccount: async () => ({
      id: "acct_test123456",
      chargesEnabled: false,
      detailsSubmitted: false,
      livemode: false,
    }),
    saveProfileState: async () => {},
    createAccountLink: async () => ({
      url: "https://connect.stripe.test/setup/acct_test",
    }),
    createLoginLink: async () => ({
      url: "https://connect.stripe.test/login/acct_test",
    }),
    returnUrl: "https://example.com/return",
    refreshUrl: "https://example.com/refresh",
    ...overrides,
  };
}

Deno.test("status returns payouts_ready false for new hosts", async () => {
  const handler = connectAccountHandler(dependencies());
  const response = await handler(request({ action: "status" }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.connected, false);
  assertEquals(body.payouts_ready, false);
});

Deno.test("onboard creates account and returns Stripe link", async () => {
  let savedAccount = "";
  const handler = connectAccountHandler(
    dependencies({
      saveProfileState: async (input) => {
        savedAccount = input.accountId;
      },
    }),
  );
  const response = await handler(request({ action: "onboard" }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(savedAccount, "acct_test123456");
  assertEquals(body.url, "https://connect.stripe.test/setup/acct_test");
  assertEquals(body.connected, true);
});

Deno.test("onboard skips link when payouts already ready", async () => {
  let linkCalls = 0;
  const handler = connectAccountHandler(
    dependencies({
      loadProfileState: async () =>
        state({
          accountId: "acct_test123456",
          chargesEnabled: true,
          detailsSubmitted: true,
        }),
      retrieveAccount: async () => ({
        id: "acct_test123456",
        chargesEnabled: true,
        detailsSubmitted: true,
        livemode: false,
      }),
      createAccountLink: async () => {
        linkCalls++;
        return { url: "https://connect.stripe.test/setup/unused" };
      },
    }),
  );
  const response = await handler(request({ action: "onboard" }));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(linkCalls, 0);
  assertEquals(body.payouts_ready, true);
  assertEquals(body.url, undefined);
});

Deno.test("dashboard requires completed onboarding", async () => {
  const handler = connectAccountHandler(dependencies());
  const response = await handler(request({ action: "dashboard" }));
  assertEquals(response.status, 409);
  assertEquals((await response.json()).error_code, "connect_not_ready");
});

Deno.test("GET returns lightweight return page", async () => {
  const handler = connectAccountHandler(dependencies());
  const response = await handler(
    new Request("https://functions.example/connect-account", { method: "GET" }),
  );
  assertEquals(response.status, 200);
  assertEquals(
    response.headers.get("content-type")?.includes("text/html"),
    true,
  );
  const html = await response.text();
  if (!html.includes("Return to Parkd")) {
    throw new Error("Expected return page copy");
  }
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}
