import { handleOrganizerRequest } from "./handler.ts";
import { createResendSender } from "./resend.ts";

const sendEmail = createResendSender(
  Deno.env.get("RESEND_API_KEY"),
  Deno.env.get("ORGANIZER_FROM_EMAIL"),
);

Deno.serve((request) => handleOrganizerRequest(request, sendEmail));
