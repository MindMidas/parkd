import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type NotificationRow = {
  id: string;
  user_id: string;
  title: string;
  body: string;
  data_json: Record<string, unknown> | null;
};

type PushTokenRow = {
  token: string;
  platform: string;
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const dispatchToken = Deno.env.get("DISPATCH_NOTIFICATIONS_TOKEN");
    if (dispatchToken) {
      const auth = req.headers.get("Authorization") ?? "";
      if (auth !== `Bearer ${dispatchToken}`) {
        return json({ error: "Unauthorized" }, 401);
      }
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRole);

    const { data: notifications, error: notificationsErr } = await admin
      .from("notifications")
      .select("id,user_id,title,body,data_json")
      .is("push_sent_at", null)
      .order("created_at", { ascending: true })
      .limit(100);

    if (notificationsErr) {
      return json({ error: notificationsErr.message }, 500);
    }
    if (!notifications || notifications.length === 0) {
      return json({ sent: 0, failed: 0, skipped: 0 }, 200);
    }

    let sent = 0;
    let failed = 0;
    let skipped = 0;

    for (const n of notifications as NotificationRow[]) {
      const { count: unreadCount } = await admin
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_id", n.user_id)
        .eq("is_read", false);

      const { data: tokenRows, error: tokenErr } = await admin
        .from("user_push_tokens")
        .select("token,platform")
        .eq("user_id", n.user_id);

      if (tokenErr) {
        await setPushError(admin, n.id, tokenErr.message);
        failed++;
        continue;
      }

      const tokens = (tokenRows ?? []) as PushTokenRow[];
      if (tokens.length === 0) {
        skipped++;
        continue;
      }

      const results = await Promise.all(
        tokens.map((t) => sendPush(
          t,
          n.title,
          n.body,
          n.data_json ?? {},
          unreadCount ?? 0,
        )),
      );
      const hasFailure = results.some((r) => r.ok === false);
      if (hasFailure) {
        const firstError = results.find((r) => r.ok === false)?.error ??
          "push delivery failed";
        await setPushError(admin, n.id, firstError);
        failed++;
      } else {
        await admin
          .from("notifications")
          .update({ push_sent_at: new Date().toISOString(), push_error: null })
          .eq("id", n.id);
        sent++;
      }
    }

    return json({ sent, failed, skipped }, 200);
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message ?? "Server error" }, 500);
  }
});

async function setPushError(
  admin: ReturnType<typeof createClient>,
  notificationId: string,
  errorMessage: string,
) {
  await admin
    .from("notifications")
    .update({ push_error: errorMessage.slice(0, 500) })
    .eq("id", notificationId);
}

async function sendPush(
  tokenRow: PushTokenRow,
  title: string,
  body: string,
  data: Record<string, unknown>,
  unreadCount: number,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const token = tokenRow.token.trim();
  if (token.length === 0) {
    return { ok: false, error: "empty push token" };
  }

  // Free-tier/non-production path: only Expo-style push tokens are supported.
  if (!token.startsWith("ExponentPushToken[")) {
    return { ok: false, error: "unsupported token type for dispatcher" };
  }
  return sendExpoPush(token, title, body, data, unreadCount);
}

async function sendExpoPush(
  token: string,
  title: string,
  body: string,
  data: Record<string, unknown>,
  unreadCount: number,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const res = await fetch("https://exp.host/--/api/v2/push/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify({
      to: token,
      title,
      body,
      data: { ...data, unread_count: unreadCount },
      sound: "default",
      badge: unreadCount,
    }),
  });

  if (!res.ok) {
    return { ok: false, error: `push provider http ${res.status}` };
  }

  const payload = await res.json().catch(() => null) as
    | { data?: { status?: string; message?: string } }
    | null;
  const status = payload?.data?.status;
  if (status && status !== "ok") {
    return {
      ok: false,
      error: payload?.data?.message ?? "push provider returned non-ok status",
    };
  }
  return { ok: true };
}

function json(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
