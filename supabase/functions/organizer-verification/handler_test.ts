import { handleOrganizerRequest } from "./handler.ts";

const applicant = "a1000000-0000-4000-8000-000000000001";
const organization = "b1000000-0000-4000-8000-000000000001";
const application = "c1000000-0000-4000-8000-000000000001";
const contact = "executive@example.org";

function check(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("verification binds the code to the signed-in applicant and organization", async (test) => {
  const env = {
    SUPABASE_URL: "https://supabase.example",
    SUPABASE_PUBLISHABLE_KEYS: JSON.stringify({
      default: "sb_publishable_test",
    }),
    SUPABASE_SECRET_KEYS: JSON.stringify({ default: "sb_secret_test" }),
    ORGANIZER_CODE_SECRET: "test-secret-with-more-than-32-characters",
  };
  const previous = Object.keys(env).map((key) =>
    [key, Deno.env.get(key)] as const
  );
  for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);

  const originalFetch = globalThis.fetch;
  let reservedDigest = "";
  let deliveredCode = "";
  let deliveries = 0;
  let rejectDelivery = false;
  let limited = false;
  let verifiedRequests = 0;
  const send = {
    action: "send",
    group_id: organization,
    full_name: "Faculty Representative",
    email: " Executive@EXAMPLE.org ",
    role: "faculty_representative",
    applicant: application, // Untrusted identity supplied by the client.
  };

  globalThis.fetch = async (input, init) => {
    const url = new URL(input instanceof Request ? input.url : input);
    const headers = new Headers(init?.headers);
    if (url.pathname === "/auth/v1/user") {
      return headers.get("Authorization") === "Bearer user-token"
        ? Response.json({
          id: applicant,
          email_confirmed_at: "2026-11-22T00:00:00Z",
        })
        : Response.json({ message: "Invalid token" }, { status: 401 });
    }

    check(
      headers.get("apikey") === "sb_secret_test",
      "Expected server RPC credentials",
    );
    const body = JSON.parse(init?.body as string);
    check(
      body.applicant === applicant,
      "Trusted applicant identity must come from Auth",
    );
    check(
      !("code" in body) && /^[0-9a-f]{64}$/.test(body.digest),
      "RPC should receive only a digest",
    );
    if (url.pathname.endsWith("/organizer_reserve_code")) {
      check(
        body.recipient === contact && body.organization === organization,
        "Incorrect email or group",
      );
      if (limited) return Response.json({ status: "rate_limited" });
      reservedDigest = body.digest;
      return Response.json({ status: "code_sent", id: application });
    }
    check(
      url.pathname.endsWith("/organizer_verify_code"),
      "Unexpected endpoint",
    );
    check(body.application_id === application, "Wrong application");
    verifiedRequests++;
    return Response.json(
      body.digest === reservedDigest ? "pending_review" : "invalid_code",
    );
  };

  function request(body: unknown, token = "user-token") {
    return handleOrganizerRequest(
      new Request("https://function.example", {
        method: "POST",
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: JSON.stringify(body),
      }),
      async (email, code) => {
        check(
          email === contact && /^\d{8}$/.test(code),
          "Invalid message recipient or code",
        );
        deliveries++;
        deliveredCode = code;
        if (rejectDelivery) throw new Error("Private provider response");
      },
    );
  }

  try {
    await test.step("anonymous and invalid sessions cannot request delivery", async () => {
      check(
        (await request(send, "")).status === 401,
        "Missing token was accepted",
      );
      check(
        (await request(send, "invalid-token")).status === 401,
        "Invalid token was accepted",
      );
      check(
        deliveries === 0 && !reservedDigest,
        "Invalid clients reached email delivery",
      );
    });

    await test.step("only the delivery transport receives the plaintext code", async () => {
      const result = await (await request(send)).json();
      check(
        deliveries === 1 && deliveredCode.length === 8,
        "Code was not delivered",
      );
      check(
        result.status === "code_sent" && result.id === application,
        "Send response was incorrect",
      );
      check(
        Object.keys(result).length === 2,
        "Send response exposed additional data",
      );
    });

    await test.step("the same code cannot verify another group", async () => {
      const verify = { action: "verify", id: application, code: deliveredCode };
      const result = await (await request({ ...verify, group_id: applicant }))
        .json();
      check(
        result.status === "invalid_code",
        "Digest was not bound to the group",
      );
      const valid = await (await request({ ...verify, group_id: organization }))
        .json();
      check(
        valid.status === "pending_review" && verifiedRequests === 2,
        "Correct code failed",
      );
    });

    await test.step("delivery failure and rate limiting give safe responses", async () => {
      rejectDelivery = true;
      const failure = await (await request(send)).json();
      check(
        failure.status === "delivery_failed" &&
          Object.keys(failure).length === 2,
        "Provider error leaked or was misreported",
      );
      limited = true;
      const throttled = await (await request(send)).json();
      check(
        throttled.status === "rate_limited" && deliveries === 2,
        "Rate limit sent an email",
      );
    });
  } finally {
    globalThis.fetch = originalFetch;
    for (const [key, value] of previous) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
