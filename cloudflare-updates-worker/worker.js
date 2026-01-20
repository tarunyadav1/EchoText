/**
 * EchoText Updates Worker
 *
 * Serves Sparkle appcast.xml and update files from R2 storage.
 *
 * Endpoints:
 * - GET /appcast.xml - Returns the Sparkle appcast feed
 * - GET /releases/:filename - Downloads update files from R2
 * - GET /health - Health check
 * - POST /admin/release - Create/update a release (requires auth)
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
        return jsonResponse({ status: 'ok', service: 'echotext-updates' });
      }

      // Serve appcast.xml
      if (path === '/appcast.xml') {
        return await handleAppcast(env);
      }

      // Serve release files from R2
      if (path.startsWith('/releases/')) {
        const filename = path.replace('/releases/', '');
        return await handleFileDownload(env, filename);
      }

      // Admin: Create/update release
      if (path === '/admin/release' && request.method === 'POST') {
        return await handleCreateRelease(request, env);
      }

      // Admin: List releases
      if (path === '/admin/releases' && request.method === 'GET') {
        return await handleListReleases(request, env);
      }

      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: 'Internal server error' }, 500);
    }
  }
};

/**
 * Generate and serve the appcast.xml
 */
async function handleAppcast(env) {
  // Get latest release info from KV
  const latestRelease = await env.APPCAST_KV.get('latest_release', 'json');

  if (!latestRelease) {
    // Return empty appcast if no releases yet
    const emptyAppcast = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>EchoText Updates</title>
    <link>https://echotext.app</link>
    <description>Most recent updates to EchoText</description>
    <language>en</language>
  </channel>
</rss>`;
    return new Response(emptyAppcast, {
      headers: {
        'Content-Type': 'application/xml',
        ...CORS_HEADERS,
      },
    });
  }

  // Get all releases for full appcast
  const allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [latestRelease];

  const appcast = generateAppcast(allReleases);

  return new Response(appcast, {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=300', // Cache for 5 minutes
      ...CORS_HEADERS,
    },
  });
}

/**
 * Generate Sparkle-compatible appcast XML
 */
function generateAppcast(releases) {
  const items = releases.map(release => `
    <item>
      <title>Version ${release.version}</title>
      <sparkle:version>${release.buildNumber}</sparkle:version>
      <sparkle:shortVersionString>${release.version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${release.minimumSystemVersion || '14.0'}</sparkle:minimumSystemVersion>
      <description><![CDATA[${release.releaseNotes || 'Bug fixes and improvements.'}]]></description>
      <pubDate>${release.pubDate}</pubDate>
      <enclosure
        url="${release.downloadUrl}"
        sparkle:edSignature="${release.edSignature}"
        length="${release.fileSize}"
        type="application/octet-stream"/>
    </item>`).join('\n');

  return `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>EchoText Updates</title>
    <link>https://echotext.app</link>
    <description>Most recent updates to EchoText</description>
    <language>en</language>
    ${items}
  </channel>
</rss>`;
}

/**
 * Handle file downloads from R2
 */
async function handleFileDownload(env, filename) {
  const object = await env.UPDATES_BUCKET.get(filename);

  if (!object) {
    return jsonResponse({ error: 'File not found' }, 404);
  }

  const headers = new Headers();
  headers.set('Content-Type', 'application/octet-stream');
  headers.set('Content-Disposition', `attachment; filename="${filename}"`);
  headers.set('Content-Length', object.size);
  headers.set('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year

  Object.entries(CORS_HEADERS).forEach(([key, value]) => {
    headers.set(key, value);
  });

  return new Response(object.body, { headers });
}

/**
 * Admin: Create or update a release
 * Requires Authorization header with admin secret
 */
async function handleCreateRelease(request, env) {
  // Verify admin authorization
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret || authHeader !== `Bearer ${adminSecret}`) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const body = await request.json();

  // Validate required fields
  const required = ['version', 'buildNumber', 'edSignature', 'fileSize', 'filename'];
  for (const field of required) {
    if (!body[field]) {
      return jsonResponse({ error: `Missing required field: ${field}` }, 400);
    }
  }

  const release = {
    version: body.version,
    buildNumber: body.buildNumber,
    edSignature: body.edSignature,
    fileSize: body.fileSize,
    filename: body.filename,
    downloadUrl: `https://echotext-updates.tarunyadav9761.workers.dev/releases/${body.filename}`,
    releaseNotes: body.releaseNotes || 'Bug fixes and improvements.',
    minimumSystemVersion: body.minimumSystemVersion || '14.0',
    pubDate: new Date().toUTCString(),
  };

  // Store as latest release
  await env.APPCAST_KV.put('latest_release', JSON.stringify(release));

  // Add to all releases list
  let allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [];

  // Remove existing release with same version
  allReleases = allReleases.filter(r => r.version !== release.version);

  // Add new release at the beginning
  allReleases.unshift(release);

  // Keep only last 10 releases
  allReleases = allReleases.slice(0, 10);

  await env.APPCAST_KV.put('all_releases', JSON.stringify(allReleases));

  return jsonResponse({
    success: true,
    message: 'Release created',
    release: release,
    appcastUrl: 'https://echotext-updates.tarunyadav9761.workers.dev/appcast.xml'
  });
}

/**
 * Admin: List all releases
 */
async function handleListReleases(request, env) {
  const authHeader = request.headers.get('Authorization');
  const adminSecret = env.ADMIN_SECRET;

  if (!adminSecret || authHeader !== `Bearer ${adminSecret}`) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const allReleases = await env.APPCAST_KV.get('all_releases', 'json') || [];

  return jsonResponse({ releases: allReleases });
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
