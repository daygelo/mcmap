import { SendEmailCommand, SESClient } from "npm:@aws-sdk/client-ses@3.1175.0";

import { FetchHttpHandler } from "npm:@smithy/fetch-http-handler@5.8.1";

import { handleOrganizerRequest } from "./handler.ts";

const region = Deno.env.get("ORGANIZER_SES_REGION");
const accessKeyId = Deno.env.get("ORGANIZER_SES_ACCESS_KEY_ID");
const secretAccessKey = Deno.env.get("ORGANIZER_SES_SECRET_ACCESS_KEY");
const sessionToken = Deno.env.get("ORGANIZER_SES_SESSION_TOKEN");
const source = Deno.env.get("ORGANIZER_FROM_EMAIL");

const ses = region && accessKeyId && secretAccessKey && source
  ? new SESClient({
    region,
    credentials: { accessKeyId, secretAccessKey, sessionToken },
    maxAttempts: 1,
    requestHandler: new FetchHttpHandler(),
  })
  : null;

async function sendEmail(recipient: string, code: string) {
  await ses!.send(
    new SendEmailCommand({
      Source: source,
      Destination: { ToAddresses: [recipient] },
      Message: {
        Subject: {
          Data: "Your McMap executive email verification code",
          Charset: "UTF-8",
        },
        Body: {
          Text: {
            Data:
              `Your McMap code is ${code}. It expires in 10 minutes. If you didn't request it, you can ignore this email.`,
            Charset: "UTF-8",
          },
        },
      },
    }),
    { abortSignal: AbortSignal.timeout(15_000) },
  );
}

Deno.serve((request) =>
  handleOrganizerRequest(request, ses ? sendEmail : null)
);
