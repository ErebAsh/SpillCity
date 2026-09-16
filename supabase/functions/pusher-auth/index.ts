import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Pusher from "npm:pusher@5.2.0"
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
    // 1. Authenticate the request using the Supabase JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { 
        status: 401, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    
    // Create a Supabase client configured to use the user's JWT
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    
    // Verify the user
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { 
        status: 401, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    // 2. Extract socket_id and channel_name from the request body
    // Pusher sends this as form data (application/x-www-form-urlencoded) by default, 
    // but flutter pusher channels might send JSON. Handle both.
    const contentType = req.headers.get('content-type') || ''
    
    let socketId: string
    let channelName: string

    if (contentType.includes('application/json')) {
      const body = await req.json()
      socketId = body.socket_id
      channelName = body.channel_name
    } else {
      const formData = await req.formData()
      socketId = formData.get('socket_id') as string
      channelName = formData.get('channel_name') as string
    }

    if (!socketId || !channelName) {
      return new Response(JSON.stringify({ error: 'socket_id and channel_name are required' }), { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    // 3. Ensure the user is only subscribing to their own channel
    // E.g., channelName is 'private-user-123', ensure user.id === '123'
    if (channelName.startsWith('private-user-')) {
      const targetUserId = channelName.replace('private-user-', '')
      if (targetUserId !== user.id) {
         return new Response(JSON.stringify({ error: 'Forbidden: You can only subscribe to your own channel' }), { 
          status: 403, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        })
      }
    }

    // 4. Initialize Pusher with the secret
    const pusher = new Pusher({
      appId: Deno.env.get('PUSHER_APP_ID')!,
      key: Deno.env.get('PUSHER_KEY')!,
      secret: Deno.env.get('PUSHER_SECRET')!,
      cluster: Deno.env.get('PUSHER_CLUSTER')!,
      useTLS: true
    })

    // 5. Generate the auth signature
    const authResponse = pusher.authorizeChannel(socketId, channelName)

    return new Response(JSON.stringify(authResponse), { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    })
    
  } catch (err: any) {
    console.error('[Pusher Auth Error]', err)
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
