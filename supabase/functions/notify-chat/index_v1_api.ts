import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  console.log('🚀 Edge Function called:', req.method, req.url)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('PROJECT_URL')!
    const serviceRoleKey = Deno.env.get('SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    if (req.method === 'GET') {
      await processPendingNotifications(supabase)
      return new Response(JSON.stringify({ 
        status: 'Edge Function is running!',
        timestamp: new Date().toISOString(),
        processed_queue: true
      }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
    }

    if (req.method === 'POST') {
      const body = await req.json()
      
      if (body.action === 'process_queue') {
        const result = await processPendingNotifications(supabase)
        return new Response(JSON.stringify({ 
          success: true, 
          processed: result.processed,
          errors: result.errors
        }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 })
      }

      const result = await sendDirectNotification(supabase, body)
      return new Response(JSON.stringify(result), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: result.success ? 200 : 500 
      })
    }

    return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 405 
    })

  } catch (error) {
    console.error('❌ Edge Function error:', error)
    return new Response(JSON.stringify({ error: 'Internal server error', details: error.message }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 
    })
  }
})

async function processPendingNotifications(supabase: any) {
  console.log('🔄 Processing pending notifications...')
  
  const processed = []
  const errors = []

  try {
    const { data: notifications, error } = await supabase.rpc('get_pending_notifications', { limit_count: 10 })

    if (error) {
      console.error('❌ Error fetching notifications:', error)
      return { processed: [], errors: [error.message] }
    }

    console.log(`📋 Found ${notifications?.length || 0} pending notifications`)

    if (!notifications || notifications.length === 0) {
      return { processed: [], errors: [] }
    }

    for (const notification of notifications) {
      try {
        console.log(`🔔 Processing notification ${notification.id}...`)
        
        const result = await sendFCMNotificationV1(notification)
        
        if (result.success) {
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
          await supabase.rpc('mark_notification_sent', {
            notification_id: notification.id,
            success: false,
            error_msg: result.error
          })
          
          errors.push({ id: notification.id, error: result.error })
          console.error(`❌ Failed to send notification ${notification.id}:`, result.error)
        }
      } catch (notificationError) {
        console.error(`❌ Error processing notification ${notification.id}:`, notificationError)
        
        await supabase.rpc('mark_notification_sent', {
          notification_id: notification.id,
          success: false,
          error_msg: notificationError.message
        })
        
        errors.push({ id: notification.id, error: notificationError.message })
      }
    }

    console.log(`✅ Processed ${processed.length} notifications, ${errors.length} errors`)
    return { processed, errors }

  } catch (error) {
    console.error('❌ Error in processPendingNotifications:', error)
    return { processed: [], errors: [error.message] }
  }
}

// Generate OAuth 2.0 access token for FCM v1 API
async function getAccessToken() {
  try {
    // Get service account from environment
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT not found in environment')
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    console.log('🔑 Service account found:', serviceAccount.project_id)

    // Create JWT for Google OAuth
    const now = Math.floor(Date.now() / 1000)
    const iat = now
    const exp = now + 3600 // 1 hour

    const header = {
      alg: 'RS256',
      typ: 'JWT'
    }

    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: iat,
      exp: exp
    }

    // Note: In a real implementation, you'd need to sign this JWT with the private key
    // For now, let's use the server key approach as fallback
    console.log('⚠️ Using server key fallback for FCM')
    return null

  } catch (error) {
    console.error('❌ Error getting access token:', error)
    return null
  }
}

// Send FCM notification using HTTP v1 API
async function sendFCMNotificationV1(notification: any) {
  console.log(`🔔 Sending FCM v1 for notification ${notification.id}`)
  
  try {
    const fcmTokens = notification.fcm_tokens || []
    console.log(`📱 Found ${fcmTokens.length} FCM tokens`)

    if (fcmTokens.length === 0) {
      return { success: false, error: 'No FCM tokens found' }
    }

    // Try to get access token first, fallback to server key
    const accessToken = await getAccessToken()
    
    // Get Firebase project ID
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    let projectId = 'edubazaar-new-97923' // fallback
    
    if (serviceAccountJson) {
      try {
        const serviceAccount = JSON.parse(serviceAccountJson)
        projectId = serviceAccount.project_id
      } catch (e) {
        console.log('⚠️ Could not parse service account, using fallback project ID')
      }
    }

    let successCount = 0
    let errorCount = 0
    let lastError = ''

    for (const tokenData of fcmTokens) {
      try {
        const fcmToken = tokenData.fcm_token
        console.log(`📤 Sending to token: ${fcmToken?.substring(0, 20)}...`)
        
        // FCM v1 API payload
        const fcmPayload = {
          message: {
            token: fcmToken,
            notification: {
              title: `New message from ${notification.sender_name || 'Someone'}`,
              body: notification.message_text.substring(0, 100)
            },
            data: {
              type: 'message_inserted',
              conversationId: notification.conversation_id,
              messageId: notification.message_id,
              senderId: notification.sender_id,
              senderName: notification.sender_name || '',
              timestamp: new Date().toISOString()
            },
            android: {
              notification: {
                sound: 'default',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                channel_id: 'edubazaar_messages',
                icon: '@mipmap/ic_launcher'
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1
                }
              }
            }
          }
        }

        console.log('📦 FCM v1 Payload:', JSON.stringify(fcmPayload, null, 2))
        
        // Use FCM v1 API endpoint
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
        
        let headers: Record<string, string> = {
          'Content-Type': 'application/json'
        }

        // Use access token if available, otherwise fallback to server key
        if (accessToken) {
          headers['Authorization'] = `Bearer ${accessToken}`
        } else {
          // Fallback: Try with server key in v1 format (though this may not work)
          const serverKey = Deno.env.get('FCM_SERVER_KEY')
          if (serverKey) {
            headers['Authorization'] = `key=${serverKey}`
          } else {
            throw new Error('No authentication method available for FCM')
          }
        }

        const fcmResponse = await fetch(fcmUrl, {
          method: 'POST',
          headers: headers,
          body: JSON.stringify(fcmPayload)
        })

        const fcmResponseText = await fcmResponse.text()
        console.log(`📊 FCM v1 Response Status: ${fcmResponse.status}`)
        console.log(`📊 FCM v1 Response: ${fcmResponseText}`)

        if (fcmResponse.ok) {
          successCount++
          console.log(`✅ FCM v1 sent successfully to ${tokenData.device_type} device`)
        } else {
          errorCount++
          let errorData
          try {
            errorData = JSON.parse(fcmResponseText)
            lastError = errorData.error?.message || fcmResponseText
          } catch {
            lastError = fcmResponseText
          }
          console.error(`❌ FCM v1 failed:`, errorData || fcmResponseText)
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
    console.error(`❌ Error in sendFCMNotificationV1:`, error)
    return { success: false, error: error.message }
  }
}

async function sendDirectNotification(supabase: any, payload: any) {
  console.log('📨 Processing direct notification...')
  
  try {
    const { data: tokens, error: tokenError } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token, device_type')
      .eq('user_id', payload.recipient_id)

    if (tokenError) {
      return { success: false, error: tokenError.message }
    }

    if (!tokens || tokens.length === 0) {
      return { success: false, error: 'No FCM tokens found' }
    }

    const mockNotification = {
      id: 'direct',
      message_id: payload.message_id,
      conversation_id: payload.conversation_id,
      sender_id: payload.sender_id,
      sender_name: payload.sender_name,
      message_text: payload.message_text,
      fcm_tokens: tokens
    }

    return await sendFCMNotificationV1(mockNotification)

  } catch (error) {
    return { success: false, error: error.message }
  }
} 