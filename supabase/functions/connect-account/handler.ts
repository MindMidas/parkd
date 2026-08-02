import {
  assertOnlyKeys,
  assertPostJson,
  errorResponse,
  HttpError,
  json,
  optionsResponse,
  readJsonObject,
  requestIdFor,
  requiredString,
  safeLog,
} from "../_shared/http.ts";

const ACCOUNT_PATTERN = /^acct_[A-Za-z0-9]+$/;

export type ConnectAction = "status" | "onboard" | "dashboard";

export interface ConnectUser {
  id: string;
  email?: string;
}

export interface ConnectProfileState {
  accountId: string | null;
  chargesEnabled: boolean;
  detailsSubmitted: boolean;
}

export interface StripeConnectAccount {
  id: string;
  chargesEnabled: boolean;
  detailsSubmitted: boolean;
}

export interface ConnectDependencies {
  authenticate(req: Request): Promise<ConnectUser>;
  loadProfileState(userId: string): Promise<ConnectProfileState>;
  createExpressAccount(input: {
    userId: string;
    email?: string;
  }): Promise<StripeConnectAccount>;
  retrieveAccount(accountId: string): Promise<StripeConnectAccount>;
  saveProfileState(input: {
    userId: string;
    accountId: string;
    chargesEnabled: boolean;
    detailsSubmitted: boolean;
  }): Promise<void>;
  createAccountLink(input: {
    accountId: string;
    returnUrl: string;
    refreshUrl: string;
  }): Promise<{ url: string }>;
  createLoginLink(accountId: string): Promise<{ url: string }>;
  returnUrl: string;
  refreshUrl: string;
}

export function connectAccountHandler(
  dependencies: ConnectDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const requestId = requestIdFor(req);
    if (req.method === "OPTIONS") return optionsResponse(req, requestId);

    if (req.method === "GET") {
      return connectReturnHtml(requestId);
    }

    try {
      assertPostJson(req);
      const user = await dependencies.authenticate(req);
      const body = await readJsonObject(req);
      assertOnlyKeys(body, ["action"]);
      const action = requiredString(body, "action", { maxLength: 32 }) as ConnectAction;
      if (action !== "status" && action !== "onboard" && action !== "dashboard") {
        throw new HttpError(400, "invalid_action", "action must be status, onboard, or dashboard.");
      }

      let state = await dependencies.loadProfileState(user.id);
      let account: StripeConnectAccount | null = null;

      if (state.accountId) {
        account = await dependencies.retrieveAccount(state.accountId);
        await dependencies.saveProfileState({
          userId: user.id,
          accountId: account.id,
          chargesEnabled: account.chargesEnabled,
          detailsSubmitted: account.detailsSubmitted,
        });
        state = {
          accountId: account.id,
          chargesEnabled: account.chargesEnabled,
          detailsSubmitted: account.detailsSubmitted,
        };
      }

      if (action === "status") {
        return json(req, statusPayload(state), 200, requestId);
      }

      if (action === "dashboard") {
        if (!state.accountId || !state.detailsSubmitted) {
          throw new HttpError(
            409,
            "connect_not_ready",
            "Finish payout setup before opening the Stripe dashboard.",
          );
        }
        const link = await dependencies.createLoginLink(state.accountId);
        safeLog("info", "connect_dashboard_link", {
          request_id: requestId,
          user_id: user.id,
        });
        return json(
          req,
          { ...statusPayload(state), url: link.url },
          200,
          requestId,
        );
      }

      // onboard
      if (!account) {
        account = await dependencies.createExpressAccount({
          userId: user.id,
          email: user.email,
        });
        if (!ACCOUNT_PATTERN.test(account.id)) {
          throw new HttpError(500, "connect_misconfigured", "Stripe account id is invalid.");
        }
        await dependencies.saveProfileState({
          userId: user.id,
          accountId: account.id,
          chargesEnabled: account.chargesEnabled,
          detailsSubmitted: account.detailsSubmitted,
        });
        state = {
          accountId: account.id,
          chargesEnabled: account.chargesEnabled,
          detailsSubmitted: account.detailsSubmitted,
        };
      }

      if (state.chargesEnabled && state.detailsSubmitted) {
        return json(req, statusPayload(state), 200, requestId);
      }

      const link = await dependencies.createAccountLink({
        accountId: state.accountId!,
        returnUrl: dependencies.returnUrl,
        refreshUrl: dependencies.refreshUrl,
      });
      safeLog("info", "connect_onboard_link", {
        request_id: requestId,
        user_id: user.id,
        account_id: state.accountId,
      });
      return json(
        req,
        { ...statusPayload(state), url: link.url },
        200,
        requestId,
      );
    } catch (error) {
      return errorResponse(req, error, requestId);
    }
  };
}

function statusPayload(state: ConnectProfileState) {
  return {
    connected: state.accountId != null,
    charges_enabled: state.chargesEnabled,
    details_submitted: state.detailsSubmitted,
    payouts_ready: state.chargesEnabled && state.detailsSubmitted,
  };
}

function connectReturnHtml(requestId: string): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Parkd payouts</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 0; padding: 2rem;
      background: #f6f7f9; color: #12263a; }
    main { max-width: 28rem; margin: 3rem auto; background: #fff;
      border-radius: 16px; padding: 1.5rem; box-shadow: 0 8px 30px rgba(0,0,0,.06); }
    h1 { font-size: 1.25rem; margin: 0 0 .5rem; }
    p { margin: 0; line-height: 1.45; color: #4b5c6b; }
  </style>
</head>
<body>
  <main>
    <h1>Return to Parkd</h1>
    <p>Payout setup is saved with Stripe. Open the Parkd app and pull to refresh Earnings if the status has not updated yet.</p>
  </main>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "x-request-id": requestId,
      "access-control-allow-origin": "*",
    },
  });
}
