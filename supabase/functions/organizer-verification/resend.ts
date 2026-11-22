export type EmailDelivery =
  | "accepted"
  | "email_unavailable"
  | "email_rate_limited";

export type VerificationEmailSender = (
  recipient: string,
  code: string,
) => Promise<EmailDelivery>;

export function createResendSender(
  apiKey: string | undefined,
  from: string | undefined,
): VerificationEmailSender | null {
  if (!apiKey?.trim() || !from?.trim()) return null;

  return async (recipient, code) => {
    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(15_000),
        headers: {
          Authorization: `Bearer ${apiKey.trim()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: from.trim(),
          to: [recipient],
          subject: "Your McMap executive verification code",
          text: [
            "You requested a verification code for your McMap organizer application.",
            `Your verification code is ${code}.`,
            "Enter this code in McMap within 10 minutes. Keep it private.",
            "If you did not request this code, you can ignore this email.",
            "McMap",
          ].join("\n\n"),
        }),
      });
      if (!response.ok) {
        await response.body?.cancel();
        return response.status === 429
          ? "email_rate_limited"
          : "email_unavailable";
      }
      const result = await response.json();
      return typeof result?.id === "string" && result.id.trim()
        ? "accepted"
        : "email_unavailable";
    } catch {
      // Provider responses can contain sensitive message or request data.
      return "email_unavailable";
    }
  };
}
