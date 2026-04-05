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
    
    // Secrets de Firebase (hardcodeados para este proyecto)
    const serviceAccount = {
      project_id: 'keepgoing-3344f',
      private_key_id: '0efa9b8d248ea46467dfb3210f17e6ca31b3ee7f',
      private_key: [
        '-----BEGIN PRIVATE KEY-----',
        'MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCeG32X9fj8lWzg',
        '+wO50RhdpI2L3P+baVZ77w7OZIb8iBegYEXVzctAJzpaHo+GnY9pdvbcJ8rhq5qK',
        'S/EqFRaTENGv2kKYFQUnCGYIJjWRRf56BMxi/ViQEEjioXf8MXrRN8cmb4Zsp6ex',
        'H8Qvyy/cp5Er5RUNCb1S4lKLoTPBsar+Y3OlnDXkQ/Ow7xazgU60su6v7D04DDx2',
        'D1SPSX6/9tT4SFNWX60dwTkp6oWMPI1BQRJtBVAwWRQCcCRdgrO5bIfj8CKSapvT',
        'J8Y8q9rb2STMuoCLa6/SzXy44EACvtMnUsIzrBU1V9J67pKZIyEaw6Y+7pT1EbCQ',
        'iGkDATUhAgMBAAECggEAMduUauenmSsbtwShA6cyylDaS/koZ587pQBZSG99+8OE',
        'w8+oJghr6DKWnZWWiApGj6jyprErsqdVJ/hTuAQHZt/+Z7hpmKDES69D0Z0O9l0+',
        'psa9lxeyJlfkTAdEGXSW+MPgmre/iaMC6AGO8c1erfPvfQqT7VUdbTYudpaihhkc',
        'YCOL0bQAzuPEYUX34ljZfd1xSjxNMptn2QnQR0Y209Aizu20PdjA1OWaUvQryOmT',
        'SeGhl8m0P4PMNn95voRGeHGtBDb0oclxxUb6H60GdsY9N5aGGLrxI9U6eISHBDaM',
        'ciaP4yNYfRB+bpqF9Zs6dvCFdSUg+HxjyQ40ZoP+qwKBgQDLuOwkTpVL2M79Dsir',
        '5n3kDZY9RxJ9+IvFHBY/gGEglfQvkgcO2NEHAtf4QwSZH88QZr1DtesDaf1ELAj3',
        '9WDKFBnJfOho4Zx9A/Uykhx8soCY8tVayjlJ0aTe2ja1R5QYi2pQEHhyY2GWhv01',
        'Hy4kw+QA6+0t86OdaIK31KjqVwKBgQDGrf8S+VtzVVh4MmBGnSo3HpAI0uVvaeh5',
        '0socvk972YTPKxMw9h8y866EUyM0y3IGbrj0f0hH3eZidgpqRlPbpthT6T0RB56w',
        'Zkf4gi6fQKTIjPFfESygrE7Yk2qQoweXN2EtXH7sgBUr15bOyWM2WLUEO54MpuZe',
        'ppnWW8UhRwKBgDVzaGnCQIOs9+oHdfk8OW2bbv7W5fAtRSbLTr8MhO9SyMWub7Gi',
        'i31mbpnRo6Q1Z1OrUR8x3N6BcZTwZM4CEIoUqgtmfWf/Qdq/Lhc9pMHG59y5Yec3',
        'Rb6rhbF+2XnItP+XnKYzHBcPIiyncEn+y1GUH/9p50n2Mch8AkgPQN5zAoGALrqB',
        'wb6wSaILGsoOZs1UPn6LteeUWu335Z80Nip0m1Z/rBIfg2Z/1AYIR8sd/q7S9LxZ',
        '9/dv0qdYJlRJAtHjq0fEnYe/+x9lrWuBBevod0BHAXxU0N1DN88PBFU3vSj7Ag/e',
        'ZULZ/1nooNUl/SDUmtWmTYaQF72xdRWOHSKcbMUCgYAB0aZ7fddymLFQur4IVN3Q',
        'oAovUDb9Dz8EMFBU/U2vbVlXxFc8ZZRIAT6OgCz7f6/P+lQXTdh9muH7wVKYQkiX',
        '4YXWUBKoaBsNJ5KKuI/NhhfjUBDc7odykLRx/cEzC9bmYv2H84POHQZl3dXxB8QD',
        'x4z4dH40OheI1/7Rja0T4Q==',
        '-----END PRIVATE KEY-----'
      ].join('\n'),
      client_email: 'firebase-adminsdk-fbsvc@keepgoing-3344f.iam.gserviceaccount.com'
    }
    
    const accessToken = await getAccessTokenFromServiceAccount(serviceAccount)

    // ============================================
    // CLIENTE SUPABASE
    // ============================================

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const now = new Date()

    // 1. Obtener dispositivos
    const { data: devices, error: devicesError } = await supabase
      .from('devices')
      .select('id, fcm_token, platform, interval_seconds, last_notified_at')
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

    // 3. Obtener quote aleatoria
    const { data: quotes, error: quoteError } = await supabase
      .from('quotes')
      .select('id, text, author')
      .limit(10)

    if (quoteError || !quotes || quotes.length === 0) {
      throw new Error('No hay quotes disponibles')
    }

    const quote = quotes[Math.floor(Math.random() * quotes.length)]
    console.log('Quote seleccionada:', quote.text.substring(0, 30) + '...')

    // 4. Enviar notificaciones usando FCM v1 API
    const fcmUrl = 'https://fcm.googleapis.com/v1/projects/keepgoing-3344f/messages:send'

    const results = await Promise.allSettled(
      devicesToNotify.map(async (device: any) => {
        const title = quote.author 
          ? `Quote de ${quote.author}` 
          : 'Keep Going 💪'
        
        const body = quote.text.length > 100 
          ? quote.text.substring(0, 100) + '...' 
          : quote.text

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
                  quote_id: quote.id,
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

    return new Response(
      JSON.stringify({
        message: `Notificaciones: ${successful} enviadas, ${failed} fallidas`,
        quote: {
          id: quote.id,
          text: quote.text.substring(0, 50),
          author: quote.author
        },
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
