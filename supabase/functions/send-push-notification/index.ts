import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"

const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  // Enable CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
  }

  try {
    const { sender_id, title, body, data } = await req.json();

    if (!sender_id || !title || !body) {
      return new Response(JSON.stringify({ error: "Missing parameters" }), {
        status: 400,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get the sender's couple_id
    const { data: sender, error: senderErr } = await supabase
      .from('users')
      .select('couple_id')
      .eq('id', sender_id)
      .single();

    if (senderErr || !sender?.couple_id) {
      return new Response(JSON.stringify({ error: "Sender not found or not paired" }), {
        status: 404,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    // 2. Find the partner's id
    const { data: partner, error: partnerErr } = await supabase
      .from('users')
      .select('id')
      .eq('couple_id', sender.couple_id)
      .neq('id', sender_id)
      .single();

    if (partnerErr || !partner) {
      return new Response(JSON.stringify({ error: "Partner not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    // 3. Get partner device tokens
    const { data: tokenRows, error: tokenErr } = await supabase
      .from('user_fcm_tokens')
      .select('token')
      .eq('user_id', partner.id);

    if (tokenErr || !tokenRows || tokenRows.length === 0) {
      return new Response(JSON.stringify({ message: "No registered tokens found for partner" }), {
        status: 200,
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    const tokens = tokenRows.map((r) => r.token);

    // 4. Generate FCM OAuth2 Access Token using Deno and Firebase credentials
    if (!FIREBASE_SERVICE_ACCOUNT) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON secret in Supabase dashboard");
    }
    const credentials = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
    const accessToken = await getAccessToken(credentials);

    // 5. Send FCM alerts
    const results = [];
    for (const token of tokens) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${credentials.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: token,
              notification: { title, body },
              data: data || {},
            },
          }),
        }
      );
      results.push({ token, status: response.status });
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
    });
  }
});

async function getAccessToken(credentials: any): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: credentials.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const jwt = await generateJWT(header, claim, credentials.private_key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  return data.access_token;
}

async function generateJWT(header: any, claim: any, privateKeyPem: string): Promise<string> {
  const textEncoder = new TextEncoder();
  const base64UrlEncode = (str: string) => btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaim = base64UrlEncode(JSON.stringify(claim));
  const signingInput = `${encodedHeader}.${encodedClaim}`;

  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKeyPem
    .substring(privateKeyPem.indexOf(pemHeader) + pemHeader.length, privateKeyPem.indexOf(pemFooter))
    .replace(/\s/g, "");
  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    textEncoder.encode(signingInput)
  );

  const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));
  return `${signingInput}.${encodedSignature}`;
}
