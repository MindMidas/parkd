import "jsr:@supabase/functions-js@2/edge-runtime.d.ts";

import { adminClient, runtimeConfig, stripeClient } from "../_shared/runtime.ts";
import { authenticateRateLimited } from "../_shared/rate_limit.ts";
import { getOrCreateStripeCustomer } from "../_shared/stripe_customer.ts";
import { createSetupIntentHandler } from "./handler.ts";

const config = runtimeConfig();
const admin = adminClient(config);
const stripe = stripeClient(config.stripeSecretKey);

const handler = createSetupIntentHandler({
  authenticate: (req) =>
    authenticateRateLimited(req, config, admin, "setup_intent", {
      userLimit: 5,
      ipLimit: 15,
      windowSeconds: 60,
    }),
  getOrCreateCustomer: (userId) => getOrCreateStripeCustomer(stripe, admin, userId),
  async createSetupIntent(input) {
    const intent = await stripe.setupIntents.create(
      {
        customer: input.customerId,
        payment_method_types: ["card"],
        usage: "off_session",
        metadata: {
          supabase_user_id: input.userId,
          environment: "portfolio_demo",
        },
      },
      { idempotencyKey: input.idempotencyKey },
    );
    return {
      id: intent.id,
      clientSecret: intent.client_secret,
      livemode: intent.livemode,
    };
  },
});

Deno.serve(handler);
