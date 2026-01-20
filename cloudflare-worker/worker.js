/**
 * EchoText License Server
 * Cloudflare Worker + KV for license validation with machine binding
 *
 * Environment Variables Required:
 * - GUMROAD_PRODUCT_ID: Your Gumroad product ID
 * - API_SECRET: Secret key for admin operations (optional)
 *
 * KV Namespace Required:
 * - LICENSE_KV: For storing license -> machine bindings
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Content-Type': 'application/json',
};

/**
 * Verify license key with Gumroad API
 */
async function verifyWithGumroad(licenseKey, productId) {
  const response = await fetch('https://api.gumroad.com/v2/licenses/verify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      product_id: productId,
      license_key: licenseKey,
      increment_uses_count: 'false', // Don't increment, we track ourselves
    }),
  });

  const data = await response.json();
  return data;
}

/**
 * Handle license activation
 * POST /activate
 * Body: { license_key, machine_id }
 */
async function handleActivate(request, env) {
  try {
    const { license_key, machine_id } = await request.json();

    if (!license_key || !machine_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'missing_parameters',
        message: 'License key and machine ID are required',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Verify with Gumroad
    const gumroadResponse = await verifyWithGumroad(license_key, env.GUMROAD_PRODUCT_ID);

    if (!gumroadResponse.success) {
      return new Response(JSON.stringify({
        success: false,
        error: 'invalid_license',
        message: 'Invalid license key. Please check your key and try again.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Check if license is refunded or disputed
    if (gumroadResponse.purchase?.refunded || gumroadResponse.purchase?.disputed) {
      return new Response(JSON.stringify({
        success: false,
        error: 'license_revoked',
        message: 'This license has been refunded or disputed.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Check existing binding
    const existingBinding = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

    if (existingBinding) {
      // License already activated
      if (existingBinding.machine_id === machine_id) {
        // Same machine - just return success
        return new Response(JSON.stringify({
          success: true,
          message: 'License already activated on this device',
          license_info: {
            email: gumroadResponse.purchase?.email,
            product_name: gumroadResponse.purchase?.product_name,
            created_at: gumroadResponse.purchase?.created_at,
            variants: gumroadResponse.purchase?.variants,
          },
          activated_at: existingBinding.activated_at,
        }), { headers: CORS_HEADERS });
      } else {
        // Different machine - reject
        return new Response(JSON.stringify({
          success: false,
          error: 'already_activated',
          message: 'This license is already activated on another device. Please deactivate it first or contact support.',
        }), { status: 400, headers: CORS_HEADERS });
      }
    }

    // Create new binding
    const binding = {
      machine_id: machine_id,
      activated_at: new Date().toISOString(),
      email: gumroadResponse.purchase?.email,
      product_name: gumroadResponse.purchase?.product_name,
    };

    await env.LICENSE_KV.put(`license:${license_key}`, JSON.stringify(binding));

    return new Response(JSON.stringify({
      success: true,
      message: 'License activated successfully',
      license_info: {
        email: gumroadResponse.purchase?.email,
        product_name: gumroadResponse.purchase?.product_name,
        created_at: gumroadResponse.purchase?.created_at,
        variants: gumroadResponse.purchase?.variants,
      },
      activated_at: binding.activated_at,
    }), { headers: CORS_HEADERS });

  } catch (error) {
    console.error('Activation error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'server_error',
      message: 'An error occurred. Please try again later.',
    }), { status: 500, headers: CORS_HEADERS });
  }
}

/**
 * Handle license verification
 * POST /verify
 * Body: { license_key, machine_id }
 */
async function handleVerify(request, env) {
  try {
    const { license_key, machine_id } = await request.json();

    if (!license_key || !machine_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'missing_parameters',
        message: 'License key and machine ID are required',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Check binding in KV
    const existingBinding = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

    if (!existingBinding) {
      return new Response(JSON.stringify({
        success: false,
        error: 'not_activated',
        message: 'License not activated. Please activate your license first.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    if (existingBinding.machine_id !== machine_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'wrong_machine',
        message: 'License is activated on a different device.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Optionally re-verify with Gumroad (to check for refunds)
    const gumroadResponse = await verifyWithGumroad(license_key, env.GUMROAD_PRODUCT_ID);

    if (!gumroadResponse.success) {
      // License no longer valid on Gumroad - remove binding
      await env.LICENSE_KV.delete(`license:${license_key}`);
      return new Response(JSON.stringify({
        success: false,
        error: 'license_invalid',
        message: 'License is no longer valid.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    if (gumroadResponse.purchase?.refunded || gumroadResponse.purchase?.disputed) {
      // License revoked - remove binding
      await env.LICENSE_KV.delete(`license:${license_key}`);
      return new Response(JSON.stringify({
        success: false,
        error: 'license_revoked',
        message: 'This license has been refunded or disputed.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'License valid',
      license_info: {
        email: gumroadResponse.purchase?.email,
        product_name: gumroadResponse.purchase?.product_name,
        created_at: gumroadResponse.purchase?.created_at,
        variants: gumroadResponse.purchase?.variants,
      },
      activated_at: existingBinding.activated_at,
    }), { headers: CORS_HEADERS });

  } catch (error) {
    console.error('Verification error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'server_error',
      message: 'An error occurred. Please try again later.',
    }), { status: 500, headers: CORS_HEADERS });
  }
}

/**
 * Handle license deactivation
 * POST /deactivate
 * Body: { license_key, machine_id }
 */
async function handleDeactivate(request, env) {
  try {
    const { license_key, machine_id } = await request.json();

    if (!license_key || !machine_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'missing_parameters',
        message: 'License key and machine ID are required',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Check binding
    const existingBinding = await env.LICENSE_KV.get(`license:${license_key}`, 'json');

    if (!existingBinding) {
      return new Response(JSON.stringify({
        success: false,
        error: 'not_activated',
        message: 'License is not activated.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    if (existingBinding.machine_id !== machine_id) {
      return new Response(JSON.stringify({
        success: false,
        error: 'wrong_machine',
        message: 'You can only deactivate from the device where the license is activated.',
      }), { status: 400, headers: CORS_HEADERS });
    }

    // Remove binding
    await env.LICENSE_KV.delete(`license:${license_key}`);

    return new Response(JSON.stringify({
      success: true,
      message: 'License deactivated successfully. You can now activate on another device.',
    }), { headers: CORS_HEADERS });

  } catch (error) {
    console.error('Deactivation error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'server_error',
      message: 'An error occurred. Please try again later.',
    }), { status: 500, headers: CORS_HEADERS });
  }
}

/**
 * Health check endpoint
 * GET /health
 */
function handleHealth() {
  return new Response(JSON.stringify({
    success: true,
    message: 'EchoText License Server is running',
    timestamp: new Date().toISOString(),
  }), { headers: CORS_HEADERS });
}

/**
 * Main request handler
 */
export default {
  async fetch(request, env, ctx) {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Route requests
    switch (path) {
      case '/activate':
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: CORS_HEADERS,
          });
        }
        return handleActivate(request, env);

      case '/verify':
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: CORS_HEADERS,
          });
        }
        return handleVerify(request, env);

      case '/deactivate':
        if (request.method !== 'POST') {
          return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: CORS_HEADERS,
          });
        }
        return handleDeactivate(request, env);

      case '/health':
      case '/':
        return handleHealth();

      default:
        return new Response(JSON.stringify({ error: 'Not found' }), {
          status: 404,
          headers: CORS_HEADERS,
        });
    }
  },
};
