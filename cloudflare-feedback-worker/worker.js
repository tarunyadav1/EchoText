/**
 * EchoText Feedback Worker
 *
 * Receives and stores user feedback from the EchoText app.
 *
 * Endpoints:
 * - POST /submit - Submit new feedback
 * - GET /health - Health check
 * - GET /admin/feedback - List all feedback (requires auth)
 * - GET /admin/feedback/:id - Get specific feedback (requires auth)
 * - DELETE /admin/feedback/:id - Delete feedback (requires auth)
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    try {
      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'ok', service: 'echotext-feedback' });
      }

      // Submit feedback
      if (path === '/submit' && request.method === 'POST') {
        return await handleSubmitFeedback(request, env);
      }

      // Admin: List feedback
      if (path === '/admin/feedback' && request.method === 'GET') {
        return await handleListFeedback(request, env);
      }

      // Admin: Get specific feedback
      if (path.startsWith('/admin/feedback/') && request.method === 'GET') {
        const id = path.replace('/admin/feedback/', '');
        return await handleGetFeedback(request, env, id);
      }

      // Admin: Delete feedback
      if (path.startsWith('/admin/feedback/') && request.method === 'DELETE') {
        const id = path.replace('/admin/feedback/', '');
        return await handleDeleteFeedback(request, env, id);
      }

      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: 'Internal server error' }, 500);
    }
  }
};

/**
 * Handle feedback submission
 */
async function handleSubmitFeedback(request, env) {
  const body = await request.json();

  // Validate required fields
  if (!body.type || !body.message) {
    return jsonResponse({ success: false, message: 'Missing required fields: type, message' }, 400);
  }

  // Validate message length
  if (body.message.length > 5000) {
    return jsonResponse({ success: false, message: 'Message too long (max 5000 characters)' }, 400);
  }

  // Generate ticket ID
  const ticketId = generateTicketId();

  // Create feedback record
  const feedback = {
    id: ticketId,
    type: body.type,
    message: body.message,
    email: body.email || null,
    appVersion: body.appVersion || 'unknown',
    buildNumber: body.buildNumber || 'unknown',
    macOSVersion: body.macOSVersion || 'unknown',
    systemInfo: body.systemInfo || null,
    timestamp: body.timestamp || new Date().toISOString(),
    receivedAt: new Date().toISOString(),
    status: 'new',
    ip: request.headers.get('CF-Connecting-IP') || 'unknown',
    country: request.headers.get('CF-IPCountry') || 'unknown',
  };

  // Store feedback
  await env.FEEDBACK_KV.put(
    `feedback:${ticketId}`,
    JSON.stringify(feedback),
    { expirationTtl: 60 * 60 * 24 * 365 } // Keep for 1 year
  );

  // Add to index for listing
  await addToIndex(env, ticketId, feedback.timestamp);

  // Send notification if webhook is configured
  if (env.NOTIFICATION_WEBHOOK) {
    ctx.waitUntil(sendNotification(env, feedback));
  }

  console.log(`Feedback received: ${ticketId} - ${body.type}`);

  return jsonResponse({
    success: true,
    message: 'Feedback received. Thank you!',
    ticketId: ticketId
  });
}

/**
 * Add feedback ID to chronological index
 */
async function addToIndex(env, ticketId, timestamp) {
  const indexKey = 'feedback:index';
  const existingIndex = await env.FEEDBACK_KV.get(indexKey, 'json') || [];

  existingIndex.unshift({ id: ticketId, timestamp });

  // Keep only last 1000 entries in index
  const trimmedIndex = existingIndex.slice(0, 1000);

  await env.FEEDBACK_KV.put(indexKey, JSON.stringify(trimmedIndex));
}

/**
 * Handle listing all feedback (admin only)
 */
async function handleListFeedback(request, env) {
  if (!verifyAdmin(request, env)) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const url = new URL(request.url);
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
  const offset = parseInt(url.searchParams.get('offset') || '0');

  const index = await env.FEEDBACK_KV.get('feedback:index', 'json') || [];
  const page = index.slice(offset, offset + limit);

  // Fetch full feedback records
  const feedbackList = await Promise.all(
    page.map(async (item) => {
      const feedback = await env.FEEDBACK_KV.get(`feedback:${item.id}`, 'json');
      return feedback;
    })
  );

  return jsonResponse({
    feedback: feedbackList.filter(Boolean),
    total: index.length,
    limit,
    offset
  });
}

/**
 * Handle getting specific feedback (admin only)
 */
async function handleGetFeedback(request, env, id) {
  if (!verifyAdmin(request, env)) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const feedback = await env.FEEDBACK_KV.get(`feedback:${id}`, 'json');

  if (!feedback) {
    return jsonResponse({ error: 'Feedback not found' }, 404);
  }

  return jsonResponse(feedback);
}

/**
 * Handle deleting feedback (admin only)
 */
async function handleDeleteFeedback(request, env, id) {
  if (!verifyAdmin(request, env)) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  await env.FEEDBACK_KV.delete(`feedback:${id}`);

  // Remove from index
  const index = await env.FEEDBACK_KV.get('feedback:index', 'json') || [];
  const newIndex = index.filter(item => item.id !== id);
  await env.FEEDBACK_KV.put('feedback:index', JSON.stringify(newIndex));

  return jsonResponse({ success: true, message: 'Feedback deleted' });
}

/**
 * Send notification to webhook (Discord/Slack)
 */
async function sendNotification(env, feedback) {
  const emoji = {
    'Bug Report': '🐛',
    'Feature Request': '💡',
    'General Feedback': '💬',
    'Question': '❓'
  }[feedback.type] || '📝';

  const message = {
    content: null,
    embeds: [{
      title: `${emoji} New ${feedback.type}`,
      description: feedback.message.substring(0, 500) + (feedback.message.length > 500 ? '...' : ''),
      color: feedback.type === 'Bug Report' ? 0xFF6B6B : 0x4ECDC4,
      fields: [
        { name: 'Ticket ID', value: feedback.id, inline: true },
        { name: 'App Version', value: `${feedback.appVersion} (${feedback.buildNumber})`, inline: true },
        { name: 'macOS', value: feedback.macOSVersion, inline: true },
        ...(feedback.email ? [{ name: 'Email', value: feedback.email, inline: true }] : []),
        { name: 'Country', value: feedback.country, inline: true },
      ],
      timestamp: feedback.timestamp
    }]
  };

  try {
    await fetch(env.NOTIFICATION_WEBHOOK, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(message)
    });
  } catch (error) {
    console.error('Failed to send notification:', error);
  }
}

/**
 * Verify admin authorization
 */
function verifyAdmin(request, env) {
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret) return false;
  return authHeader === `Bearer ${adminSecret}`;
}

/**
 * Generate a human-readable ticket ID
 */
function generateTicketId() {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `FB-${timestamp}-${random}`;
}

/**
 * Helper: Create JSON response
 */
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...CORS_HEADERS,
    },
  });
}
