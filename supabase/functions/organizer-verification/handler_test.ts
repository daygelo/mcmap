import { handleOrganizerRequest } from "./handler.ts";
import { createResendSender } from "./resend.ts";

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
  let providerStatus = 200;
  let expired = false;
  let reservations = 0;
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
    if (url.hostname === "api.resend.com") {
      check(
        url.pathname === "/emails" && init?.method === "POST",
        "Wrong Resend request",
      );
      check(
        headers.get("Authorization") === "Bearer re_test",
        "Wrong Resend API key",
      );
      check(init.signal instanceof AbortSignal, "Missing delivery timeout");
      const message = JSON.parse(init.body as string);
      check(message.from === "McMap <verify@mail.example.org>", "Wrong sender");
      check(
        JSON.stringify(message.to) === JSON.stringify([contact]),
        "Wrong recipient",
      );
      const code = message.text.match(/verification code is (\d{8})\./)?.[1];
      check(
        code && message.text.includes("10 minutes"),
        "Invalid code or expiration text",
      );
      deliveredCode = code;
      deliveries++;
      return Response.json(
        providerStatus === 200
          ? { id: "resend-message" }
          : { message: "Private provider response" },
        { status: providerStatus },
      );
    }

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
      reservations++;
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
      expired
        ? "expired"
        : body.digest === reservedDigest
        ? "pending_review"
        : "invalid_code",
    );
  };

  const sender = createResendSender(
    "re_test",
    "McMap <verify@mail.example.org>",
  );
  function request(body: unknown, token = "user-token", transport = sender) {
    return handleOrganizerRequest(
      new Request("https://function.example", {
        method: "POST",
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: JSON.stringify(body),
      }),
      transport,
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

    await test.step("missing configuration and invalid email do not reserve a code", async () => {
      const before = reservations;
      for (
        const transport of [
          createResendSender(undefined, "verify@mail.example.org"),
          createResendSender("re_test", " "),
        ]
      ) {
        const response = await request(send, "user-token", transport);
        check(
          response.status === 503 &&
            (await response.json()).status === "email_unavailable",
          "Missing configuration reported incorrectly",
        );
      }
      const invalid = await request({ ...send, email: "not-an-email" });
      check(
        invalid.status === 400 &&
          (await invalid.json()).status === "invalid_email",
        "Invalid email accepted",
      );
      check(reservations === before, "Invalid requests consumed a reservation");
    });

    await test.step("provider errors do not report success or expose details", async () => {
      for (const status of [401, 403, 422, 429, 503]) {
        providerStatus = status;
        const response = await request(send);
        const failure = await response.json();
        check(
          response.status === (status === 429 ? 429 : 503),
          "Wrong error status",
        );
        check(
          failure.status ===
              (status === 429 ? "email_rate_limited" : "email_unavailable") &&
            Object.keys(failure).length === 1,
          "Provider error leaked or was misreported",
        );
      }
      const before = deliveries;
      limited = true;
      check(
        (await (await request(send)).json()).status === "rate_limited",
        "Missing app limit",
      );
      check(deliveries === before, "App limit reached the provider");
    });

    await test.step("incorrect and expired codes remain distinct", async () => {
      const verify = {
        action: "verify",
        id: application,
        group_id: organization,
      };
      const differentCode = deliveredCode === "00000000"
        ? "11111111"
        : "00000000";
      check(
        (await (await request({ ...verify, code: differentCode })).json())
          .status === "invalid_code",
        "Wrong code was accepted",
      );
      expired = true;
      check(
        (await (await request({ ...verify, code: deliveredCode })).json())
          .status === "expired",
        "Expired code was accepted",
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

Deno.test("Resend timeout and an unconfirmed success fail closed", async () => {
  const originalFetch = globalThis.fetch;
  const sender = createResendSender("re_test", "verify@mail.example.org")!;
  try {
    globalThis.fetch = () =>
      Promise.reject(new DOMException("timeout", "TimeoutError"));
    check(
      await sender(contact, "01234567") === "email_unavailable",
      "Timeout reported success",
    );
    globalThis.fetch = () => Promise.resolve(Response.json({}));
    check(
      await sender(contact, "01234567") === "email_unavailable",
      "No provider ID reported success",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});
