import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  console.log('🚀 Edge Function called:', req.method, req.url)

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('PROJECT_URL')!
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY')!
    
    console.log('🔧 Creating Supabase client...')
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    // Check if this is a GET request (health check)
    if (req.method === 'GET') {
      console.log('❤️ Health check request')
      
      // Also process pending notifications on health check
      await processPendingNotifications(supabase)
      
      return new Response(
        JSON.stringify({ 
          status: 'Edge Function is running!',
          timestamp: new Date().toISOString(),
          processed_queue: true
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200 
        }
      )
    }

    // Handle POST request (manual notification or queue processing trigger)
    if (req.method === 'POST') {
      console.log('📨 POST request received')
      
      const body = await req.json()
      console.log('📦 Request body:', JSON.stringify(body, null, 2))

      // Check if this is a queue processing request
      if (body.action === 'process_queue') {
        console.log('🔄 Processing notification queue...')
        const result = await processPendingNotifications(supabase)
        
        return new Response(
          JSON.stringify({ 
            success: true, 
            processed: result.processed,
            errors: result.errors
          }),
          { 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200 
          }
        )
      }

      // Handle direct notification (legacy support)
      const result = await sendDirectNotification(supabase, body)
      
      return new Response(
        JSON.stringify(result),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: result.success ? 200 : 500
        }
      )
    }

    // Invalid method
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405 
      }
    )

  } catch (error) {
    console.error('❌ Edge Function error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        details: error.message 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500 
      }
    )
  }
})

// Process pending notifications from queue
async function processPendingNotifications(supabase: any) {
  console.log('🔄 Starting to process pending notifications...')
  
  const processed = []
  const errors = []

  try {
    // Get pending notifications from queue
    const { data: notifications, error } = await supabase
      .rpc('get_pending_notifications', { limit_count: 10 })

    if (error) {
      console.error('❌ Error fetching pending notifications:', error)
      return { processed: [], errors: [error.message] }
    }

    console.log(`📋 Found ${notifications?.length || 0} pending notifications`)

    if (!notifications || notifications.length === 0) {
      return { processed: [], errors: [] }
    }

    // Process each notification
    for (const notification of notifications) {
      try {
        console.log(`🔔 Processing notification ${notification.id}...`)
        
        const result = await sendFCMNotification(notification)
        
        if (result.success) {
          // Mark as sent
          await supabase.rpc('mark_notification_sent', {
            notification_id: notification.id,
            success: true
          })
          
          processed.push({
            id: notification.id,
            message_id: notification.message_id,
            status: 'sent'
          })
          
          console.log(`✅ Notification ${notification.id} sent successfully`)
        } else {
          // Mark as failed
          await supabase.rpc('mark_notification_sent', {
            notification_id: notification.id,
            success: false,
            error_msg: result.error
          })
          
          errors.push({
            id: notification.id,
            error: result.error
          })
          
          console.error(`❌ Failed to send notification ${notification.id}:`, result.error)
        }
      } catch (notificationError) {
        console.error(`❌ Error processing notification ${notification.id}:`, notificationError)
        
        // Mark as failed
        await supabase.rpc('mark_notification_sent', {
          notification_id: notification.id,
          success: false,
          error_msg: notificationError.message
        })
        
        errors.push({
          id: notification.id,
          error: notificationError.message
        })
      }
    }

    console.log(`✅ Processed ${processed.length} notifications, ${errors.length} errors`)
    return { processed, errors }

  } catch (error) {
    console.error('❌ Error in processPendingNotifications:', error)
    return { processed: [], errors: [error.message] }
  }
}

// Send FCM notification using LEGACY API (still works for now)
async function sendFCMNotification(notification: any) {
  console.log(`🔔 Sending FCM for notification ${notification.id}`)
  
  try {
    const fcmTokens = notification.fcm_tokens || []
    console.log(`📱 Found ${fcmTokens.length} FCM tokens`)

    if (fcmTokens.length === 0) {
      return { success: false, error: 'No FCM tokens found' }
    }

    // Get FCM server key
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')
    if (!fcmServerKey) {
      console.error('❌ FCM_SERVER_KEY not found in environment')
      return { success: false, error: 'FCM_SERVER_KEY not configured' }
    }

    console.log('🔑 FCM server key found:', fcmServerKey.substring(0, 20) + '...')

    let successCount = 0
    let errorCount = 0
    let lastError = ''

    // Send to all FCM tokens using LEGACY API
    for (const tokenData of fcmTokens) {
      try {
        const fcmToken = tokenData.fcm_token
        console.log(`📤 Sending to token: ${fcmToken?.substring(0, 20)}...`)
        
        const fcmPayload = {
          to: fcmToken,
          notification: {
            title: `New message from ${notification.sender_name || 'Someone'}`,
            body: notification.message_text.substring(0, 100),
            sound: 'default',
            icon: '@mipmap/ic_launcher',
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          data: {
            type: 'message_inserted',
            conversationId: notification.conversation_id,
            messageId: notification.message_id,
            senderId: notification.sender_id,
            senderName: notification.sender_name || '',
            timestamp: new Date().toISOString()
          },
          priority: 'high',
          content_available: true
        }

        console.log('📦 FCM Payload:', JSON.stringify(fcmPayload, null, 2))
        
        const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `key=${fcmServerKey}`
          },
          body: JSON.stringify(fcmPayload)
        })

        const fcmResponseText = await fcmResponse.text()
        console.log(`📊 FCM Response Status: ${fcmResponse.status}`)
        console.log(`📊 FCM Response Text: ${fcmResponseText}`)

        let fcmResult
        try {
          fcmResult = JSON.parse(fcmResponseText)
        } catch {
          fcmResult = { error: fcmResponseText }
        }

        if (fcmResponse.ok && fcmResult.success === 1) {
          successCount++
          console.log(`✅ FCM sent successfully to ${tokenData.device_type} device`)
        } else {
          errorCount++
          lastError = fcmResult.results?.[0]?.error || fcmResult.error || 'Unknown FCM error'
          console.error(`❌ FCM failed:`, fcmResult)
        }
      } catch (tokenError) {
        errorCount++
        lastError = tokenError.message
        console.error(`❌ Error sending to token:`, tokenError)
      }
    }

    if (successCount > 0) {
      return { 
        success: true, 
        message: `Sent to ${successCount}/${fcmTokens.length} devices` 
      }
    } else {
      return { 
        success: false, 
        error: `Failed to send to all ${fcmTokens.length} devices. Last error: ${lastError}` 
      }
    }

  } catch (error) {
    console.error(`❌ Error in sendFCMNotification:`, error)
    return { success: false, error: error.message }
  }
}

// Send direct notification (legacy support)
async function sendDirectNotification(supabase: any, payload: any) {
  console.log('📨 Processing direct notification...')
  
  try {
    // Get FCM tokens for recipient
    const { data: tokens, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token, device_type')
      .eq('user_id', payload.recipient_id)

    if (tokenError) {
      console.error('❌ Error fetching FCM tokens:', tokenError)
      return { success: false, error: tokenError.message }
    }

    if (!tokens || tokens.length === 0) {
      console.log('⚠️ No FCM tokens found for recipient')
      return { success: false, error: 'No FCM tokens found' }
    }

    console.log(`📱 Found ${tokens.length} FCM tokens for direct notification`)

    const mockNotification = {
      id: 'direct',
      message_id: payload.message_id,
      conversation_id: payload.conversation_id,
      sender_id: payload.sender_id,
      sender_name: payload.sender_name,
      message_text: payload.message_text,
      fcm_tokens: tokens
    }

    return await sendFCMNotification(mockNotification)

  } catch (error) {
    console.error('❌ Error in sendDirectNotification:', error)
    return { success: false, error: error.message }
  }
} 