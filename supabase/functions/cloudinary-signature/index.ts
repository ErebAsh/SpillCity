import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts"
import { encodeHex } from "https://deno.land/std@0.203.0/encoding/hex.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Authenticate the request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Missing Authorization header')

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    // 2. Parse request
    const { folder } = await req.json()
    if (!folder) throw new Error('folder is required')

    // 3. Generate signature
    const apiSecret = Deno.env.get('CLOUDINARY_API_SECRET')!
    const apiKey = Deno.env.get('CLOUDINARY_API_KEY')!
    const cloudName = Deno.env.get('CLOUDINARY_CLOUD_NAME')!
    
    const timestamp = Math.floor(Date.now() / 1000).toString()
    const stringToSign = `folder=${folder}&timestamp=${timestamp}${apiSecret}`

    // Hash using SHA-1
    const messageBuffer = new TextEncoder().encode(stringToSign)
    const hashBuffer = await crypto.subtle.digest('SHA-1', messageBuffer)
    const signature = encodeHex(new Uint8Array(hashBuffer))

    return new Response(JSON.stringify({ 
      signature, 
      timestamp, 
      apiKey, 
      cloudName 
    }), { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })
    
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: err.message === 'Unauthorized' ? 401 : 400 
    })
  }
})
