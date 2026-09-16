import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"
import Pusher from "npm:pusher@5.2.0"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Function to generate Google OAuth2 token for Firebase Messaging
async function getAccessToken(clientEmail: string, privateKeyPem: string) {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  // Replace actual newlines represented as \n
  const cleanedKey = privateKeyPem.replace(/\\n/g, "\n");
  const pemContents = cleanedKey
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");
  
  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const textEncoder = new TextEncoder();
  const base64UrlEncode = (str: string) =>
    btoa(str)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const tokenInput = `${encodedHeader}.${encodedPayload}`;

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    textEncoder.encode(tokenInput)
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  const jwt = `${tokenInput}.${signature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(`Failed to obtain Google access token: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { targetUserId, event, data: eventData } = await req.json()

    if (!targetUserId || !event) {
      return new Response(
        JSON.stringify({ error: 'targetUserId and event are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    // Initialize Pusher
    const pusher = new Pusher({
      appId: Deno.env.get('PUSHER_APP_ID')!,
      key: Deno.env.get('PUSHER_KEY')!,
      secret: Deno.env.get('PUSHER_SECRET')!,
      cluster: Deno.env.get('PUSHER_CLUSTER')!,
      useTLS: true
    })

    // 1. Trigger Pusher Event
    await pusher.trigger(`private-user-${targetUserId}`, event, eventData)
    console.log(`[Signaling] Pusher event "${event}" triggered to user "${targetUserId}"`)

    // 2. Query Recipient User for FCM token if this is a calling alert event
    const eventsForPush = ['incoming-call', 'call-accepted', 'call-ended', 'call-rejected'];
    if (eventsForPush.includes(event)) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseServiceKey)

      const { data: recipient, error: dbError } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', targetUserId)
        .maybeSingle()

      if (dbError) {
        console.error('[Signaling] Database error:', dbError)
      }

      if (recipient?.fcm_token) {
        const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!
        const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!
        const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')!

        try {
          const accessToken = await getAccessToken(clientEmail, privateKey)

          // Map event names to FCM data types
          let fcmType = 'unknown';
          if (event === 'incoming-call') fcmType = 'incoming_call';
          else if (event === 'call-accepted') fcmType = 'call_accepted';
          else if (event === 'call-ended') fcmType = 'call_ended';
          else if (event === 'call-rejected') fcmType = 'call_rejected';

          const messageData: Record<string, string> = {
            type: fcmType,
            callerId: event === 'incoming-call' ? eventData.caller.id : targetUserId,
          }

          if (event === 'incoming-call') {
            messageData.callerName = eventData.caller.name || 'Someone'
            messageData.avatarUrl = eventData.caller.avatar || ''
            messageData.channelName = eventData.channelName
            messageData.callType = eventData.type || 'voice'
          }

          const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                message: {
                  token: recipient.fcm_token,
                  data: messageData,
                  android: {
                    priority: 'high',
                    ttl: event === 'incoming-call' ? '86400s' : '60s',
                  },
                },
              }),
            }
          )

          if (fcmResponse.ok) {
            console.log(`[Signaling] FCM push sent successfully for event "${event}"`)
          } else {
            const fcmErr = await fcmResponse.text()
            console.error(`[Signaling] FCM push failed: ${fcmErr}`)
          }
        } catch (fcmErr) {
          console.error('[Signaling] Error sending FCM push:', fcmErr)
        }
      } else {
        console.log(`[Signaling] Recipient ${targetUserId} has no registered FCM token. Skipping push.`)
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (err: any) {
    console.error('[Signaling Error]', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
