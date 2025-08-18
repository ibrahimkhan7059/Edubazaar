import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { userId, userEmail, userName, timestamp } = await req.json()

    // Validate required fields
    if (!userId || !userEmail || !userName) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Send welcome email using a reliable email service
    // You can use SendGrid, Mailgun, or any other email service
    const emailSent = await sendWelcomeEmail(userEmail, userName)

    if (emailSent) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'Welcome email sent successfully',
          userId,
          userEmail,
          userName,
          timestamp 
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      return new Response(
        JSON.stringify({ error: 'Failed to send welcome email' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function sendWelcomeEmail(userEmail: string, userName: string): Promise<boolean> {
  try {
    // Option 1: Using SendGrid (recommended)
    // You'll need to add SENDGRID_API_KEY to your Supabase secrets
    const sendgridApiKey = Deno.env.get('SENDGRID_API_KEY')
    
    if (sendgridApiKey) {
      return await sendWithSendGrid(userEmail, userName, sendgridApiKey)
    }

    // Option 2: Using Mailgun
    const mailgunApiKey = Deno.env.get('MAILGUN_API_KEY')
    const mailgunDomain = Deno.env.get('MAILGUN_DOMAIN')
    
    if (mailgunApiKey && mailgunDomain) {
      return await sendWithMailgun(userEmail, userName, mailgunApiKey, mailgunDomain)
    }

    // Option 3: Using Resend (modern email service)
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    
    if (resendApiKey) {
      return await sendWithResend(userEmail, userName, resendApiKey)
    }

    // Fallback: Log that no email service is configured
    console.log('No email service configured. Please set up SendGrid, Mailgun, or Resend API keys.')
    return false

  } catch (error) {
    console.error('Error sending welcome email:', error)
    return false
  }
}

async function sendWithSendGrid(userEmail: string, userName: string, apiKey: string): Promise<boolean> {
  try {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [
          {
            to: [{ email: userEmail, name: userName }],
            subject: 'Welcome to EduBazaar! 🎉',
          },
        ],
        from: { email: 'noreply@edubazaar.com', name: 'EduBazaar Team' },
        content: [
          {
            type: 'text/html',
            value: generateWelcomeEmailHTML(userName),
          },
        ],
      }),
    })

    return response.ok
  } catch (error) {
    console.error('SendGrid error:', error)
    return false
  }
}

async function sendWithMailgun(userEmail: string, userName: string, apiKey: string, domain: string): Promise<boolean> {
  try {
    const formData = new FormData()
    formData.append('from', 'EduBazaar Team <noreply@edubazaar.com>')
    formData.append('to', userEmail)
    formData.append('subject', 'Welcome to EduBazaar! 🎉')
    formData.append('html', generateWelcomeEmailHTML(userName))

    const response = await fetch(`https://api.mailgun.net/v3/${domain}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${btoa(`api:${apiKey}`)}`,
      },
      body: formData,
    })

    return response.ok
  } catch (error) {
    console.error('Mailgun error:', error)
    return false
  }
}

async function sendWithResend(userEmail: string, userName: string, apiKey: string): Promise<boolean> {
  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'EduBazaar <noreply@edubazaar.com>',
        to: [userEmail],
        subject: 'Welcome to EduBazaar! 🎉',
        html: generateWelcomeEmailHTML(userName),
      }),
    })

    return response.ok
  } catch (error) {
    console.error('Resend error:', error)
    return false
  }
}

function generateWelcomeEmailHTML(userName: string): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to EduBazaar!</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
        .button { display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 25px; margin: 20px 0; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Welcome to EduBazaar!</h1>
          <p>Your Student Marketplace & Learning Community</p>
        </div>
        
        <div class="content">
          <h2>Hello ${userName}!</h2>
          
          <p>Welcome to EduBazaar! We're thrilled to have you join our community of students, learners, and educators.</p>
          
          <h3>🚀 What you can do on EduBazaar:</h3>
          <ul>
            <li><strong>Buy & Sell:</strong> List textbooks, electronics, and more</li>
            <li><strong>Join Study Groups:</strong> Connect with fellow students</li>
            <li><strong>Attend Events:</strong> Participate in workshops and meetups</li>
            <li><strong>Chat & Network:</strong> Build meaningful connections</li>
          </ul>
          
          <div style="text-align: center;">
            <a href="https://edubazaar.com" class="button">Start Exploring</a>
          </div>
          
          <h3>💡 Getting Started Tips:</h3>
          <ol>
            <li>Complete your profile with a photo and bio</li>
            <li>Browse the marketplace for items you need</li>
            <li>Join study groups in your field of interest</li>
            <li>Connect with other students in your area</li>
          </ol>
          
          <p>If you have any questions or need help getting started, feel free to reach out to our support team.</p>
          
          <p>Happy learning and connecting!</p>
          
          <p><strong>The EduBazaar Team</strong></p>
        </div>
        
        <div class="footer">
          <p>© 2024 EduBazaar. All rights reserved.</p>
          <p>This email was sent to you because you signed up for EduBazaar.</p>
        </div>
      </div>
    </body>
    </html>
  `
} 