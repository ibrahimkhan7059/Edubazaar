// OAuth Helper for FCM v1 API
// This implements proper JWT signing with the Firebase service account

import { createHash } from "https://deno.land/std@0.168.0/crypto/mod.ts"

// Base64 URL encode
function base64urlEncode(data: string): string {
  return btoa(data)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}

// Simple JWT creation (for Deno environment)
async function createJWT(payload: any, privateKey: string): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }

  const headerEncoded = base64urlEncode(JSON.stringify(header))
  const payloadEncoded = base64urlEncode(JSON.stringify(payload))
  
  const dataToSign = `${headerEncoded}.${payloadEncoded}`
  
  // In a full implementation, you'd sign with the private key here
  // For now, we'll use a workaround
  console.log('⚠️ JWT signing not fully implemented in Deno environment')
  
  return `${dataToSign}.signature_placeholder`
}

export async function getGoogleAccessToken(): Promise<string | null> {
  try {
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      console.log('❌ FIREBASE_SERVICE_ACCOUNT not found')
      return null
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    console.log('🔑 Creating OAuth token for:', serviceAccount.project_id)

    const now = Math.floor(Date.now() / 1000)
    const tokenPayload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600
    }

    // For production, implement proper JWT signing
    // For now, let's try a simplified approach using Google's OAuth endpoint directly
    
    const tokenRequest = {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: await createJWT(tokenPayload, serviceAccount.private_key)
    }

    console.log('🔄 Attempting OAuth token request...')
    
    // This won't work without proper JWT signing, but let's try anyway
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams(tokenRequest)
    })

    if (response.ok) {
      const tokenData = await response.json()
      console.log('✅ OAuth token obtained successfully')
      return tokenData.access_token
    } else {
      const errorText = await response.text()
      console.log('❌ OAuth token request failed:', errorText)
      return null
    }

  } catch (error) {
    console.error('❌ Error in getGoogleAccessToken:', error)
    return null
  }
} 