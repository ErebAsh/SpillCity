import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { RtcTokenBuilder, RtcRole } from "npm:agora-token@2.0.5"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { channelName, uid } = await req.json()

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: 'channelName is required' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
      )
    }

    const appId = Deno.env.get('AGORA_APP_ID')
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE')

    if (!appId || !appCertificate) {
      console.log('[Agora Token API] App ID or App Certificate is missing in environment variables. Falling back to tokenless mode.')
      return new Response(
        JSON.stringify({ token: null, isTokenless: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const role = RtcRole.PUBLISHER
    // Expire token in 2 hours
    const expirationTimeInSeconds = 7200
    const currentTimestamp = Math.floor(Date.now() / 1000)
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds

    const numericUid = typeof uid === 'number' ? uid : 0

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      numericUid,
      role,
      privilegeExpiredTs,
      privilegeExpiredTs
    )

    console.log(`[Agora Token API] Generated token for channel "${channelName}" (uid: ${numericUid})`)

    return new Response(
      JSON.stringify({ token, isTokenless: false }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (err: any) {
    console.error('[Agora Token API] Error generating token:', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Failed to generate token' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
