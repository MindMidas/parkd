import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";
import type Stripe from "npm:stripe@17.4.0";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import {
  connectAccountHandler,
  type ConnectProfileState,
  type StripeConnectAccount,
} from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);

const defaultReturn = `${config.supabaseUrl.replace(/\/$/, "")}/functions/v1/connect-account`;
const returnUrl = Deno.env.get("STRIPE_CONNECT_RETURN_URL")?.trim() || defaultReturn;
const refreshUrl = Deno.env.get("STRIPE_CONNECT_REFRESH_URL")?.trim() || defaultReturn;

function mapAccount(account: Stripe.Account): StripeConnectAccount {
  return {
    id: account.id,
    chargesEnabled: account.charges_enabled === true,
    detailsSubmitted: account.details_submitted === true,
  };
}

const handler = connectAccountHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "connect", {
      userLimit: 20,
      ipLimit: 40,
      windowSeconds: 60,
    }),
  async loadProfileState(userId): Promise<ConnectProfileState> {
    const { data, error } = await admin
      .from("profiles")
      .select(
        "stripe_connect_account_id, stripe_connect_charges_enabled, stripe_connect_details_submitted",
      )
      .eq("id", userId)
      .maybeSingle();
    if (error) throw error;
    if (data == null) {
      return { accountId: null, chargesEnabled: false, detailsSubmitted: false };
    }
    const accountId = typeof data.stripe_connect_account_id === "string"
      ? data.stripe_connect_account_id
      : null;
    return {
      accountId,
      chargesEnabled: data.stripe_connect_charges_enabled === true,
      detailsSubmitted: data.stripe_connect_details_submitted === true,
    };
  },
  async createExpressAccount({ userId, email }) {
    const account = await stripe.accounts.create(
      {
        type: "express",
        country: "CA",
        email: email || undefined,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_type: "individual",
        metadata: {
          application: "parkd",
          parkd_user_id: userId,
        },
      },
      { idempotencyKey: `parkd:connect-account:${userId}:v1` },
    );
    return mapAccount(account);
  },
  async retrieveAccount(accountId) {
    return mapAccount(await stripe.accounts.retrieve(accountId));
  },
  async saveProfileState(input) {
    const { error } = await admin.rpc("set_stripe_connect_state", {
      p_user_id: input.userId,
      p_account_id: input.accountId,
      p_charges_enabled: input.chargesEnabled,
      p_details_submitted: input.detailsSubmitted,
    });
    if (error) throw error;
  },
  async createAccountLink(input) {
    const link = await stripe.accountLinks.create({
      account: input.accountId,
      refresh_url: input.refreshUrl,
      return_url: input.returnUrl,
      type: "account_onboarding",
    });
    return { url: link.url };
  },
  async createLoginLink(accountId) {
    const link = await stripe.accounts.createLoginLink(accountId);
    return { url: link.url };
  },
  returnUrl,
  refreshUrl,
});

Deno.serve(handler);
