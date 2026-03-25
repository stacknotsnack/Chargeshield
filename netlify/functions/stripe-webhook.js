// Netlify serverless function — Stripe webhook handler
// Triggered by Stripe on checkout.session.completed.
// Generates a CS-XXXX-XXXX-XXXX licence key, saves it to Firestore, and emails it via Resend.
//
// Required environment variables (set in Netlify dashboard → Site config → Env vars):
//   STRIPE_SECRET_KEY        — Stripe secret key (sk_live_...)
//   STRIPE_WEBHOOK_SECRET    — Signing secret from Stripe webhook dashboard (whsec_...)
//   RESEND_API_KEY           — Resend API key (re_...)
//   FIREBASE_SERVICE_ACCOUNT — Base64-encoded Firebase service account JSON

const stripe = require('stripe');
const admin = require('firebase-admin');

// Initialise Firebase Admin SDK once (functions are reused across invocations)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT, 'base64').toString('utf8'))
    ),
  });
}

const db = admin.firestore();

// ---------------------------------------------------------------------------
// Licence key generator — CS-XXXX-XXXX-XXXX (alphanumeric, uppercase)
// ---------------------------------------------------------------------------
function generateLicenceKey() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const group = () =>
    Array.from({ length: 4 }, () =>
      chars[Math.floor(Math.random() * chars.length)]
    ).join('');
  return `CS-${group()}-${group()}-${group()}`;
}

// ---------------------------------------------------------------------------
// Email template
// ---------------------------------------------------------------------------
function buildEmailHtml(licenceKey) {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; color: #1a1a1a;">
  <h1 style="color: #1565C0; margin-bottom: 4px;">ChargeShield Pro</h1>
  <p style="color: #666; margin-top: 0;">Your licence key is ready</p>

  <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;">

  <p>Thank you for purchasing ChargeShield Pro. Here is your personal licence key:</p>

  <div style="background: #f5f5f5; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
    <span style="font-family: monospace; font-size: 22px; font-weight: bold; letter-spacing: 3px; color: #1565C0;">${licenceKey}</span>
  </div>

  <h3>How to activate:</h3>
  <ol style="line-height: 2;">
    <li>Open the <strong>ChargeShield</strong> app on your Android phone</li>
    <li>Tap <strong>Settings</strong> → <strong>Manage Subscription</strong></li>
    <li>Scroll down to <em>"Already purchased? Enter your licence key"</em></li>
    <li>Type or paste your key above and tap <strong>Activate Licence Key</strong></li>
  </ol>

  <p style="background: #fff8e1; border-left: 4px solid #f9a825; padding: 12px 16px; border-radius: 4px;">
    <strong>Keep this email safe.</strong> Your licence key cannot be recovered if lost.
    Each key activates one device.
  </p>

  <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 24px 0;">

  <p style="color: #666; font-size: 13px;">
    Questions? Reply to this email or visit
    <a href="https://chargeshield.co.uk" style="color: #1565C0;">chargeshield.co.uk</a>
  </p>
  <p style="color: #666; font-size: 13px;">The ChargeShield Team</p>
</body>
</html>
  `.trim();
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  const sig = event.headers['stripe-signature'];
  if (!sig) {
    return { statusCode: 400, body: 'Missing stripe-signature header' };
  }

  // Stripe requires the raw request body for signature verification.
  // Netlify passes it as event.body (base64-encoded when isBase64Encoded=true).
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64')
    : event.body;

  let stripeEvent;
  try {
    stripeEvent = stripe(process.env.STRIPE_SECRET_KEY).webhooks.constructEvent(
      rawBody,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  console.log('Stripe event received:', stripeEvent.type);

  if (stripeEvent.type === 'checkout.session.completed') {
    const session = stripeEvent.data.object;

    // Customer email — prefer customer_details (available for guest checkouts too)
    const email =
      session.customer_details?.email ||
      session.customer_email;

    if (!email) {
      console.error('No customer email on session:', session.id);
      return { statusCode: 400, body: 'No customer email found' };
    }

    const licenceKey = generateLicenceKey();
    console.log(`Generated licence key ${licenceKey} for ${email}`);

    // Determine plan from Stripe price/product metadata if available
    const planType = session.metadata?.plan || 'monthly';

    // Save key to Firestore — server-side validation reads from here
    try {
      await db.collection('licence_keys').doc(licenceKey).set({
        key: licenceKey,
        status: 'active',
        email: email,
        plan: planType,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        activatedAt: null,
        deviceId: null,
        activationCount: 0,
        stripeSessionId: session.id,
      });
      console.log(`Licence key ${licenceKey} saved to Firestore`);
    } catch (firestoreErr) {
      // Log but don't block — email still sends so customer isn't left without their key
      console.error('Firestore save failed (non-fatal):', firestoreErr.message);
    }

    // Send via Resend
    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'ChargeShield <support@chargeshield.co.uk>',
        to: [email],
        bcc: ['support@chargeshield.co.uk'],
        subject: 'Your ChargeShield Pro Licence Key',
        html: buildEmailHtml(licenceKey),
      }),
    });

    if (!resendRes.ok) {
      const errText = await resendRes.text();
      console.error('Resend API error:', errText);
      return { statusCode: 500, body: 'Failed to send licence key email' };
    }

    console.log(`Licence key email sent to ${email}`);
  }

  return {
    statusCode: 200,
    body: JSON.stringify({ received: true }),
  };
};
