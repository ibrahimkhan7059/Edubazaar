import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  console.log('🚀 FCM v1 Edge Function called:', req.method, req.url)

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
      const result = await processPendingNotifications(supabase)
      return new Response(JSON.stringify({ 
        status: 'FCM v1 Queue Processing Complete',
        timestamp: new Date().toISOString(),
        processed: result.processed,
        errors: result.errors,
        summary: `Processed ${result.processed.length} notifications, ${result.errors.length} errors`,
        api_version: 'FCM HTTP v1 API'
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
        status: 200 
      })
    }

    if (req.method === 'POST') {
      const body = await req.json()
      
      if (body.action === 'process_queue') {
        const result = await processPendingNotifications(supabase)
        return new Response(JSON.stringify({ 
          success: true, 
          processed: result.processed,
          errors: result.errors,
          api_version: 'FCM HTTP v1 API'
        }), { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
          status: 200 
        })
      }

      // Handle direct notification sending
      const result = await sendDirectNotification(supabase, body)
      return new Response(JSON.stringify(result), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: result.success ? 200 : 500 
      })
    }

    return new Response(JSON.stringify({ error: 'Method not allowed' }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
      status: 405 
    })

  } catch (error) {
    console.error('💥 Edge Function error:', error)
    return new Response(JSON.stringify({ 
      error: 'Internal server error', 
      details: error.message,
      timestamp: new Date().toISOString()
    }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500 
    })
  }
})

// Generate OAuth 2.0 access token for FCM v1 API
async function getAccessToken() {
  try {
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      console.error('❌ FIREBASE_SERVICE_ACCOUNT environment variable not found')
      return null
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    console.log('🔐 Generating OAuth token for project:', serviceAccount.project_id)

    // Create JWT header
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    }

    // Create JWT payload
    const now = Math.floor(Date.now() / 1000)
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    }

    // Encode header and payload
    const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
    const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

    // Create signature
    const message = `${encodedHeader}.${encodedPayload}`
    const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n')

    // Import private key
    const keyData = privateKey.replace('-----BEGIN PRIVATE KEY-----', '')
                              .replace('-----END PRIVATE KEY-----', '')
                              .replace(/\s/g, '')
    
    const binaryKey = Uint8Array.from(atob(keyData), c => c.charCodeAt(0))
    
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    )

    // Sign the message
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(message)
    )

    // Encode signature
    const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
                            .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

    // Create JWT
    const jwt = `${message}.${encodedSignature}`

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error('❌ Token exchange failed:', errorText)
      return null
    }

    const tokenData = await tokenResponse.json()
    console.log('✅ OAuth token generated successfully')
    return tokenData.access_token

  } catch (error) {
    console.error('💥 Error generating access token:', error)
    return null
  }
}

async function processPendingNotifications(supabase: any) {
  console.log('📋 Processing pending notifications with FCM v1...')
  
  const processed = []
  const errors = []

  try {
    // Get pending notifications using the RPC function
    const { data: notifications, error } = await supabase.rpc('get_pending_notifications', { 
      limit_count: 10 
    })

    if (error) {
      console.error('❌ Error fetching notifications:', error)
      return { processed: [], errors: [error.message] }
    }

    console.log(`📱 Found ${notifications?.length || 0} pending notifications`)

    if (!notifications || notifications.length === 0) {
      return { processed: [], errors: [] }
    }

    // Process each notification
    for (const notification of notifications) {
      try {
        console.log(`🔄 Processing notification ${notification.id}`)
        
        // Mark as processing
        await supabase.rpc('mark_notification_sent', {
          notification_id: notification.id,
          success: false,
          error_msg: 'processing_fcm_v1'
        })
        
        const result = await sendFCMv1Notification(notification)
        
        if (result.success) {
          await supabase.rpc('mark_notification_sent', {
            notification_id: notification.id,
            success: true,
            error_msg: null
          })
          
          processed.push({
            id: notification.id,
            message_id: notification.message_id,
            status: 'sent',
            result: result.message,
            api: 'FCM_v1'
          })
          
          console.log(`✅ Notification ${notification.id} sent via FCM v1`)
        } else {
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
        console.error(`💥 Error processing notification ${notification.id}:`, notificationError)
        
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

    console.log(`📊 Processed ${processed.length} notifications, ${errors.length} errors`)
    return { processed, errors }

  } catch (error) {
    console.error('💥 Error in processPendingNotifications:', error)
    return { processed: [], errors: [error.message] }
  }
}

async function sendFCMv1Notification(notification: any) {
  console.log(`📤 Sending FCM v1 for notification ${notification.id}`)
  
  try {
    const fcmTokens = notification.fcm_tokens || []
    console.log(`🔑 Found ${fcmTokens.length} FCM tokens`)

    if (fcmTokens.length === 0) {
      return { success: false, error: 'No FCM tokens found' }
    }

    // Get access token
    const accessToken = await getAccessToken()
    if (!accessToken) {
      return { success: false, error: 'Failed to get OAuth access token' }
    }

    // Get project ID
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    const serviceAccount = JSON.parse(serviceAccountJson!)
    const projectId = serviceAccount.project_id

    console.log('🔐 OAuth token obtained, sending notifications...')

    let successCount = 0
    let errorCount = 0
    let lastError = ''

    for (const tokenData of fcmTokens) {
      try {
        const fcmToken = tokenData.fcm_token
        console.log(`📲 Sending to ${tokenData.device_type} device: ${fcmToken?.substring(0, 20)}...`)
        
        // FCM v1 API payload
        const fcmPayload = {
          message: {
            token: fcmToken,
            notification: {
              title: `💬 New message from ${notification.sender_name || 'Someone'}`,
              body: (notification.message_text || 'New message').substring(0, 100),
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
                icon: '@mipmap/ic_launcher',
                color: '#6366f1'
              },
              priority: 'high'
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                  'content-available': 1
                }
              }
            }
          }
        }

        // Send to FCM v1 API
        const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`
          },
          body: JSON.stringify(fcmPayload)
        })

        const fcmResponseText = await fcmResponse.text()
        console.log(`📊 FCM v1 Response Status: ${fcmResponse.status}`)
        console.log(`📋 FCM v1 Response: ${fcmResponseText}`)

        if (fcmResponse.ok) {
          const responseData = JSON.parse(fcmResponseText)
          if (responseData.name) {
            successCount++
            console.log(`✅ FCM v1 sent successfully to ${tokenData.device_type} device`)
          } else {
            errorCount++
            lastError = `FCM v1 error: ${JSON.stringify(responseData)}`
            console.error(`❌ FCM v1 failed:`, responseData)
          }
        } else {
          errorCount++
          lastError = `HTTP ${fcmResponse.status}: ${fcmResponseText}`
          console.error(`❌ FCM v1 HTTP error:`, lastError)
        }

      } catch (tokenError) {
        errorCount++
        lastError = tokenError.message
        console.error(`💥 Error sending to token:`, tokenError)
      }
    }

    if (successCount > 0) {
      return { 
        success: true, 
        message: `📤 FCM v1: Sent to ${successCount}/${fcmTokens.length} devices successfully` 
      }
    } else {
      return { 
        success: false, 
        error: `❌ FCM v1: Failed to send to all ${fcmTokens.length} devices. Last error: ${lastError}` 
      }
    }

  } catch (error) {
    console.error(`💥 Error in sendFCMv1Notification:`, error)
    return { success: false, error: error.message }
  }
}

async function sendDirectNotification(supabase: any, payload: any) {
  console.log('📨 Processing direct FCM v1 notification...')
  
  try {
    // Get FCM tokens for the recipient
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
      return { success: false, error: 'No FCM tokens found for recipient' }
    }

    console.log(`🔑 Found ${tokens.length} FCM tokens for direct notification`)

    // Create a mock notification object for processing
    const mockNotification = {
      id: 'direct_' + Date.now(),
      message_id: payload.message_id,
      conversation_id: payload.conversation_id,
      sender_id: payload.sender_id,
      sender_name: payload.sender_name,
      message_text: payload.message_text,
      fcm_tokens: tokens
    }

    return await sendFCMv1Notification(mockNotification)

  } catch (error) {
    console.error('💥 Error in sendDirectNotification:', error)
    return { success: false, error: error.message }
  }
}

// Helper function to test if Edge Function is working
async function testFunction() {
  return {
    status: 'Edge Function is running',
    timestamp: new Date().toISOString(),
    environment: {
      hasProjectUrl: !!Deno.env.get('PROJECT_URL'),
      hasServiceRole: !!Deno.env.get('SERVICE_ROLE_KEY'),
      hasFcmKey: !!Deno.env.get('FCM_SERVER_KEY')
    }
  }
} 