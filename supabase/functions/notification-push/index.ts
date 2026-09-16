import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Function to generate Google OAuth2 token for Firebase Messaging
async function getAccessToken(clientEmail: string, privateKeyPem: string) {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
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
    const { id, user_id, actor_id, type, message, post_id } = await req.json()

    if (!user_id || !type || !message) {
      return new Response(
        JSON.stringify({ error: 'user_id, type, and message are required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 1. Fetch target user profile settings
    const { data: recipient, error: dbError } = await supabase
      .from('users')
      .select('fcm_token, notify_likes, notify_comments, notify_mentions, notify_new_posts')
      .eq('id', user_id)
      .maybeSingle()

    if (dbError) {
      console.error('[PushNotification] Database error fetching recipient:', dbError)
      return new Response(
        JSON.stringify({ error: 'Database lookup failed' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    if (!recipient?.fcm_token) {
      console.log(`[PushNotification] Recipient ${user_id} has no registered FCM token. Skipping.`)
      return new Response(
        JSON.stringify({ success: true, skipped: true, reason: 'no_fcm_token' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // 2. Preferences check
    let shouldSend = false
    if (type === 'like' && recipient.notify_likes !== false) shouldSend = true
    else if (type === 'comment' && recipient.notify_comments !== false) shouldSend = true
    else if (type === 'mention' && recipient.notify_mentions !== false) shouldSend = true
    else if (type === 'new_post' && recipient.notify_new_posts === true) shouldSend = true

    if (!shouldSend) {
      console.log(`[PushNotification] Notifications of type "${type}" disabled for user ${user_id}. Skipping.`)
      return new Response(
        JSON.stringify({ success: true, skipped: true, reason: 'preference_disabled' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // 3. Fetch actor's display name
    let senderName = 'Someone'
    if (actor_id) {
      const { data: actor } = await supabase
        .from('users')
        .select('name')
        .eq('id', actor_id)
        .maybeSingle()
      
      if (actor?.name) {
        senderName = actor.name
      }
    }

    // Get Firebase credentials
    const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!
    const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!
    const privateKey = Deno.env.get('FIREBASE_PRIVATE_KEY')!

    const accessToken = await getAccessToken(clientEmail, privateKey)

    // Send FCM message
    const bodyText = `${senderName} ${message}`

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
            data: {
              type: 'in_app_notification',
              notificationType: type,
              title: senderName,
              body: bodyText,
              postId: post_id || '',
              actorId: actor_id || '',
              notificationId: id || '',
            },
            android: {
              priority: 'high',
              ttl: '3600s',
            },
          },
        }),
      }
    )

    if (fcmResponse.ok) {
      console.log(`[PushNotification] FCM push sent successfully to user ${user_id} for event "${type}"`)
    } else {
      const fcmErr = await fcmResponse.text()
      console.error(`[PushNotification] FCM push failed: ${fcmErr}`)
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (err: any) {
    console.error('[PushNotification Error]', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
