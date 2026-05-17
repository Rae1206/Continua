// ============================================
// Edge Function - Envío de Notificaciones via FCM v1 API
// ============================================

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { createClient } = await import('npm:@supabase/supabase-js@2')

    // ============================================
    // OBTENER ACCESS TOKEN DESDE SERVICE ACCOUNT
    // ============================================

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON no configurado')
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    
    const accessToken = await getAccessTokenFromServiceAccount(serviceAccount)

    // ============================================
    // CLIENTE SUPABASE
    // ============================================

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!
    )

    const now = new Date()

    // 1. Obtener dispositivos
    const { data: devices, error: devicesError } = await supabase
      .from('devices')
      .select('id, fcm_token, platform, interval_seconds, last_notified_at, preferred_tags')
      .not('fcm_token', 'is', null)

    if (devicesError) {
      throw new Error(`Error fetching devices: ${devicesError.message}`)
    }

    if (!devices || devices.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No hay dispositivos registrados', sent: 0 }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    console.log(`Dispositivos encontrados: ${devices.length}`)

    // 2. Filtrar dispositivos que deben recibir notificación
    const devicesToNotify = devices.filter((device: any) => {
      if (!device.last_notified_at) return true
      
      const lastNotified = new Date(device.last_notified_at)
      const intervalMs = (device.interval_seconds || 900) * 1000
      const timeSinceLastNotification = now.getTime() - lastNotified.getTime()
      
      return timeSinceLastNotification >= intervalMs
    })

    console.log(`Dispositivos a notificar: ${devicesToNotify.length}`)

    if (devicesToNotify.length === 0) {
      return new Response(
        JSON.stringify({ 
          message: 'Ningún dispositivo listo para notificar',
          devices_count: devices.length
        }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }


    // 3. Obtener todas las quotes una sola vez y asignar aleatoriamente
    const { data: allQuotes, error: quotesError } = await supabase
      .from('quotes')
      .select('id, text, author, tags')

    if (quotesError) {
      throw new Error(`Error fetching quotes: ${quotesError.message}`)
    }

    if (!allQuotes || allQuotes.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No hay quotes disponibles', sent: 0 }),
        { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
      )
    }

    const quoteResults: Record<string, any> = {}

    for (const device of devicesToNotify) {
      let candidates = allQuotes

      // Filtrar por tags preferidos si existen
      if (device.preferred_tags && device.preferred_tags.length > 0) {
        const tagged = allQuotes.filter((q: any) =>
          q.tags && q.tags.some((tag: string) => device.preferred_tags.includes(tag))
        )
        if (tagged.length > 0) {
          candidates = tagged
        }
      }

      // Elegir una al azar
      const randomIndex = Math.floor(Math.random() * candidates.length)
      quoteResults[device.id] = candidates[randomIndex]
    }

    // 4. Enviar notificaciones usando FCM v1 API
    const fcmUrl = 'https://fcm.googleapis.com/v1/projects/keepgoing-3344f/messages:send'

    const results = await Promise.allSettled(
      devicesToNotify.map(async (device: any) => {
        const quote = quoteResults[device.id]
        if (!quote) {
          return { deviceId: device.id, success: false, error: 'No quote available' }
        }

        const primaryTag = quote.tags && quote.tags.length > 0 ? quote.tags[0] : 'general'

        const title = quote.author
          ? `💡 ${quote.author}`
          : '💡 Keep Going'

        const bodyText = quote.text.length > 100
          ? quote.text.substring(0, 100) + '...'
          : quote.text
        const body = '\u201C' + bodyText + '\u201D'

        try {
          const fcmResponse = await fetch(fcmUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`
            },
            body: JSON.stringify({
              message: {
                token: device.fcm_token,
                notification: {
                  title,
                  body
                },
                data: {
                  type: 'quote_notification',
                  quote_id: String(quote.id),
                  primary_tag: primaryTag,
                  click_action: 'FLUTTER_NOTIFICATION_CLICK'
                },
                android: {
                  priority: 'high'
                }
              }
            })
          })

          const fcmResult = await fcmResponse.json()
          
          console.log(`FCM Response for device ${device.id}:`, JSON.stringify(fcmResult))
          
          if (fcmResult.name) {
            // FCM v1 returns { name: "projects/.../messages/..." } on success
            // Actualizar last_notified_at
            await supabase
              .from('devices')
              .update({ 
                last_notified_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
              })
              .eq('id', device.id)

            return { deviceId: device.id, success: true }
          } else {
            console.error(`FCM Error for device ${device.id}:`, fcmResult)
            
            // Token expirado o inválido
            if (fcmResult.error?.status === 'NOT_REGISTERED' ||
                fcmResult.error?.status === 'INVALID_ARGUMENT') {
              await supabase
                .from('devices')
                .update({ fcm_token: null })
                .eq('id', device.id)
            }
            
            return { deviceId: device.id, success: false, error: fcmResult.error?.message || 'FCM error' }
          }
        } catch (error: any) {
          console.error(`FCM Error for device ${device.id}:`, error)
          return { deviceId: device.id, success: false, error: error.message }
        }
      })
    )

    const successful = results.filter(
      r => r.status === 'fulfilled' && r.value.success
    ).length
    
    const failed = results.length - successful

    console.log(`Notificaciones: ${successful} enviadas, ${failed} fallidas`)

    // Recolectar resultados detallados para debug
    const resultsDetailed = results.map((r: any) => r.status === 'fulfilled' ? r.value : { success: false, error: 'promise rejected' })

    // Obtener una quote de ejemplo para la respuesta
    const sampleQuote = Object.values(quoteResults)[0] as any

    return new Response(
      JSON.stringify({
        message: `Notificaciones: ${successful} enviadas, ${failed} fallidas`,
        quote: sampleQuote ? {
          id: sampleQuote.id,
          text: sampleQuote.text.substring(0, 50),
          author: sampleQuote.author,
          primary_tag: sampleQuote.tags?.[0] || 'general'
        } : null,
        devices_notified: successful,
        devices_skipped: failed,
        debug_results: resultsDetailed
      }),
      { 
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } 
      }
    )

  } catch (error) {
    console.error('Error en Edge Function:', error)
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Error desconocido' 
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } 
      }
    )
  }
})

// ============================================
// OBTENER ACCESS TOKEN DESDE SERVICE ACCOUNT
// ============================================

async function getAccessTokenFromServiceAccount(serviceAccount: any): Promise<string> {
  // Use jose library to sign JWT
  const { SignJWT } = await import('https://esm.sh/jose@5.2.0')
  
  // Create JWT with correct claims for Google OAuth
  const jwt = await new SignJWT({
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('1h')
    .setAudience('https://oauth2.googleapis.com/token')
    .sign(await importKey(serviceAccount.private_key))
  
  // Intercambiar por access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  })
  
  const data = await response.json()
  
  if (!data.access_token) {
    throw new Error('Failed to get access token: ' + JSON.stringify(data))
  }
  
  return data.access_token
}

// Import private key using jose
async function importKey(privateKeyPem: string) {
  const { importPKCS8 } = await import('https://esm.sh/jose@5.2.0')
  return importPKCS8(privateKeyPem, 'RS256')
}
