# EchoText License Server

Cloudflare Worker for license validation with Gumroad integration.

## Quick Start (GitHub Auto-Deploy)

The easiest way to deploy is via GitHub Actions. Once set up, any push to `cloudflare-worker/` triggers automatic deployment.

### One-Time Setup

#### 1. Create Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use template: **"Edit Cloudflare Workers"**
4. Add permission: **Account > Workers KV Storage > Edit**
5. Create and copy the token

#### 2. Get Your Account ID

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Select any domain (or Workers & Pages)
3. Find "Account ID" in the right sidebar
4. Copy it

#### 3. Create KV Namespace

```bash
# Install wrangler if you haven't
npm install -g wrangler
wrangler login

# Create the KV namespace
cd cloudflare-worker
wrangler kv:namespace create "LICENSE_KV"
```

Copy the returned ID and update `wrangler.toml`:
```toml
[[kv_namespaces]]
binding = "LICENSE_KV"
id = "paste-your-kv-id-here"
```

#### 4. Add GitHub Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `CLOUDFLARE_API_TOKEN` | Your API token from step 1 |
| `CLOUDFLARE_ACCOUNT_ID` | Your account ID from step 2 |

#### 5. Set Gumroad Product ID

```bash
wrangler secret put GUMROAD_PRODUCT_ID
# Enter your Gumroad product ID when prompted
```

#### 6. Commit and Push

```bash
git add .
git commit -m "Setup license server"
git push
```

GitHub Actions will automatically deploy the worker.

Your server will be at: `https://echotext-license-server.<your-subdomain>.workers.dev`

---

## Manual Setup (Alternative)

If you prefer manual deployment:

### 1. Install Wrangler CLI

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Create KV Namespace

```bash
cd cloudflare-worker
wrangler kv:namespace create "LICENSE_KV"
```

Update `wrangler.toml` with the returned ID.

### 4. Set Gumroad Product ID

```bash
wrangler secret put GUMROAD_PRODUCT_ID
```

### 5. Deploy

```bash
wrangler deploy
```

## API Endpoints

### POST /activate

Activate a license on a device.

```json
{
  "license_key": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "machine_id": "device-hardware-uuid"
}
```

### POST /verify

Verify a license is valid for a device.

```json
{
  "license_key": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "machine_id": "device-hardware-uuid"
}
```

### POST /deactivate

Deactivate a license (for device transfer).

```json
{
  "license_key": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
  "machine_id": "device-hardware-uuid"
}
```

### GET /health

Health check endpoint.

## Custom Domain (Optional)

To use a custom domain like `license.echotext.app`:

1. Add the domain to Cloudflare
2. Uncomment and update the `[routes]` section in `wrangler.toml`
3. Redeploy

## Testing Locally

```bash
wrangler dev
```

This starts a local server at `http://localhost:8787`

## Monitoring

View logs in real-time:

```bash
wrangler tail
```
