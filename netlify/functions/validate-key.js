// Netlify serverless function — Licence key validation
// Called by the Flutter app when a user enters a licence key.
// Checks the key exists in Firestore and binds it to the device on first activation.
//
// Required environment variables:
//   FIREBASE_SERVICE_ACCOUNT — Base64-encoded Firebase service account JSON

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8'))
    ),
  });
}

const db = admin.firestore();

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

exports.handler = async (event) => {
  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers: CORS_HEADERS, body: JSON.stringify({ error: 'Method not allowed' }) };
  }

  let key, deviceId;
  try {
    ({ key, deviceId } = JSON.parse(event.body));
  } catch {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ valid: false, reason: 'invalid_request' }) };
  }

  if (!key || !deviceId) {
    return { statusCode: 400, headers: CORS_HEADERS, body: JSON.stringify({ valid: false, reason: 'missing_fields' }) };
  }

  // Format check
  const regex = /^CS-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
  if (!regex.test(key)) {
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ valid: false, reason: 'invalid_format' }),
    };
  }

  // Look up key in Firestore
  let doc;
  try {
    doc = await db.collection('licence_keys').doc(key).get();
  } catch (err) {
    console.error('Firestore read error:', err.message);
    return {
      statusCode: 503,
      headers: CORS_HEADERS,
      body: JSON.stringify({ valid: false, reason: 'server_error' }),
    };
  }

  if (!doc.exists) {
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ valid: false, reason: 'key_not_found' }),
    };
  }

  const data = doc.data();

  // Revoked check
  if (data.status === 'revoked') {
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ valid: false, reason: 'key_revoked' }),
    };
  }

  // Already activated on a different device
  if (data.deviceId && data.deviceId !== deviceId) {
    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({ valid: false, reason: 'already_activated' }),
    };
  }

  // Activate — bind to device on first use, or re-confirm same device
  try {
    await db.collection('licence_keys').doc(key).update({
      deviceId: deviceId,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activationCount: admin.firestore.FieldValue.increment(1),
      status: 'activated',
    });
  } catch (err) {
    console.error('Firestore update error:', err.message);
    // Key is valid even if we couldn't persist the activation update
  }

  console.log(`Key ${key} validated for device ${deviceId}`);

  return {
    statusCode: 200,
    headers: CORS_HEADERS,
    body: JSON.stringify({
      valid: true,
      plan: data.plan || 'monthly',
      email: data.email,
    }),
  };
};
