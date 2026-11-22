import { createClient } from "npm:@supabase/supabase-js@2.119.2";
import type { VerificationEmailSender } from "./resend.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const emailPattern =
  /^[a-z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/;
const encoder = new TextEncoder();

function reply(status: string, http = 200, id?: string) {
  return Response.json({ status, ...(id ? { id } : {}) }, {
    status: http,
    headers: cors,
  });
}

function generateCode() {
  const random = new Uint32Array(1);
  // Rejection sampling keeps all eight-digit strings equally likely.
  do {
    crypto.getRandomValues(random);
  } while (random[0] >= 4_200_000_000);
  return (random[0] % 100_000_000).toString().padStart(8, "0");
}

async function hashCode(
  secret: string,
  profile: string,
  group: string,
  code: string,
) {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const result = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${profile}:${group}:${code}`),
  );
  return Array.from(
    new Uint8Array(result),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

export async function handleOrganizerRequest(
  request: Request,
  sendEmail: VerificationEmailSender | null,
): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (request.method !== "POST") return reply("unavailable", 405);
  const token = request.headers.get("Authorization")?.match(/^Bearer (\S+)$/i)
    ?.[1];
  if (!token) return reply("sign_in_required", 401);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const publicKey =
      JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}").default ??
        Deno.env.get("SUPABASE_ANON_KEY");
    const serverKey =
      JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}").default ??
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const secret = Deno.env.get("ORGANIZER_CODE_SECRET");
    if (!url || !publicKey || !serverKey || !secret || secret.length < 32) {
      return reply("service_unavailable", 503);
    }
    const options = {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
        detectSessionInUrl: false,
      },
    };
    const { data: { user }, error: authError } = await createClient(
      url,
      publicKey,
      options,
    ).auth.getUser(token);
    if (authError && (authError.status == null || authError.status >= 500)) {
      return reply("service_unavailable", 503);
    }
    if (authError || !user || !user.email_confirmed_at) {
      return reply("sign_in_required", 401);
    }

    const body = await request.json().catch(() => null);
    if (
      !body || typeof body.group_id !== "string" || !uuid.test(body.group_id)
    ) {
      return reply("invalid_details");
    }
    const server = createClient(url, serverKey, options);
    const group = body.group_id;
    if (body.action === "verify") {
      if (
        typeof body.id !== "string" || !uuid.test(body.id) ||
        typeof body.code !== "string" || !/^\d{8}$/.test(body.code)
      ) {
        return reply("invalid_code");
      }
      const { data, error } = await server.rpc("organizer_verify_code", {
        applicant: user.id,
        application_id: body.id,
        digest: await hashCode(secret, user.id, group, body.code),
      });
      return error ? reply("service_unavailable", 503) : reply(data);
    }

    if (
      body.action !== "send" || typeof body.email !== "string" ||
      typeof body.full_name !== "string" || typeof body.role !== "string"
    ) {
      return reply("invalid_details");
    }
    const email = body.email.trim().toLowerCase();
    const name = body.full_name.trim();
    if (email.length > 254 || !emailPattern.test(email)) {
      return reply("invalid_email", 400);
    }
    if (!name || name.length > 120) return reply("invalid_details", 400);
    if (!sendEmail) return reply("email_unavailable", 503);

    const code = generateCode();
    const { data, error } = await server.rpc("organizer_reserve_code", {
      applicant: user.id,
      organization: group,
      applicant_name: name,
      official_role: body.role,
      recipient: email,
      digest: await hashCode(secret, user.id, group, code),
    });
    if (error) return reply("service_unavailable", 503);
    if (data.status !== "code_sent") return reply(data.status);
    if (typeof data.id !== "string" || !uuid.test(data.id)) {
      return reply("service_unavailable", 503);
    }

    try {
      const delivery = await sendEmail(email, code);
      if (delivery === "accepted") return reply("code_sent", 200, data.id);
      return reply(delivery, delivery === "email_rate_limited" ? 429 : 503);
    } catch {
      return reply("email_unavailable", 503);
    }
  } catch {
    return reply("service_unavailable", 503);
  }
}
