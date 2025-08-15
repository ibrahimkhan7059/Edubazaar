import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-edge-secret',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = await req.json()
    console.log('🔔 [NOTIFY] Received payload:', payload)
    
    // Verify edge secret
    const edgeSecret = req.headers.get('x-edge-secret')
    if (edgeSecret !== 'edubazaar-secret-2024-xyz123') {
      console.error('❌ [NOTIFY] Invalid edge secret')
      throw new Error('Unauthorized')
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    console.log('🔧 [NOTIFY] Creating Supabase client...')
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    let recipientId: string
    let senderName: string
    let notificationTitle: string
    let notificationBody: string
    let conversationId: string
    let senderId: string

    if (payload.type === 'message_inserted') {
      const message = payload.message
      conversationId = message.conversation_id
      senderId = message.sender_id
      
      console.log('🔍 [NOTIFY] Processing message:', {
        conversationId,
        senderId,
        messageText: message.message_text?.substring(0, 50)
      })
      
      // Get conversation details
      console.log('🔍 [NOTIFY] Getting conversation details...')
      const { data: conversation, error: convError } = await supabase
        .from('conversations')
        .select('participant_1_id, participant_2_id')
        .eq('id', conversationId)
        .single()

      if (convError || !conversation) {
        console.error('❌ [NOTIFY] Conversation not found:', convError)
        throw new Error('Conversation not found')
      }

      // Determine recipient
      recipientId = conversation.participant_1_id === senderId 
        ? conversation.participant_2_id 
        : conversation.participant_1_id

      console.log('👤 [NOTIFY] Determined recipient:', recipientId)

      // Get sender profile
      console.log('🔍 [NOTIFY] Getting sender profile...')
      const { data: senderProfile, error: profileError } = await supabase
        .from('user_profiles')
        .select('name')
        .eq('id', senderId)
        .single()

      if (profileError) {
        console.error('❌ [NOTIFY] Error getting sender profile:', profileError)
      }

      senderName = senderProfile?.name || 'Someone'
      notificationTitle = 'New Message'
      notificationBody = `${senderName}: ${message.message_text?.substring(0, 50)}${message.message_text?.length > 50 ? '...' : ''}`

      console.log('📝 [NOTIFY] Prepared notification:', {
        title: notificationTitle,
        body: notificationBody,
        sender: senderName
      })

    } else {
      console.error('❌ [NOTIFY] Invalid notification type:', payload.type)
      throw new Error('Invalid notification type')
    }

    // Get recipient's FCM tokens
    console.log('🔍 [NOTIFY] Getting FCM tokens for user:', recipientId)
    const { data: tokens, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', recipientId)

    if (tokenError) {
      console.error('❌ [NOTIFY] Error getting FCM tokens:', tokenError)
      throw new Error('Failed to get FCM tokens')
    }

    if (!tokens || tokens.length === 0) {
      console.log('ℹ️ [NOTIFY] No FCM tokens found for user:', recipientId)
      return new Response(JSON.stringify({ success: true, message: 'No FCM tokens found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    console.log(`✅ [NOTIFY] Found ${tokens.length} FCM tokens for user:`, recipientId)

    // Send to all tokens (devices) for this user
    const fcmPromises = tokens.map(async ({ fcm_token }) => {
      if (!fcm_token) return null

      console.log('🚀 [NOTIFY] Sending FCM to token:', fcm_token.substring(0, 20) + '...')

      const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=AIzaSyBn75OeDFhyk1l3l-22ONQVf7wAGYwvATM`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: fcm_token,
          notification: {
            title: notificationTitle,
            body: notificationBody,
            sound: 'default',
            badge: '1',
            icon: '@mipmap/ic_launcher',
            android_channel_id: 'edubazaar_messages',
            tag: conversationId, // Group notifications by conversation
          },
          data: {
            type: payload.type,
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            messageId: payload.type === 'message_inserted' ? payload.message.id : '',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          priority: 'high',
          content_available: true,
          mutable_content: true,
        }),
      })

      const fcmResult = await fcmResponse.json()
      
      if (!fcmResponse.ok) {
        console.error('❌ [NOTIFY] FCM error:', {
          status: fcmResponse.status,
          result: fcmResult
        })
        return false
      }

      console.log('✅ [NOTIFY] FCM sent successfully:', fcmResult)
      return true
    })

    const results = await Promise.all(fcmPromises)
    const successCount = results.filter(Boolean).length

    console.log(`✅ [NOTIFY] Sent ${successCount} of ${tokens.length} notifications`)

    return new Response(JSON.stringify({ 
      success: true,
      sent: successCount,
      total: tokens.length
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('❌ [NOTIFY] Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
}) 