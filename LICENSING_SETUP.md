# EchoText Licensing & Auto-Update Setup Guide

This guide explains how to set up the licensing system with Gumroad and Cloudflare Workers.

## Overview

The licensing system consists of:
1. **Gumroad** - Handles payments and generates license keys
2. **Cloudflare Worker** - Validates licenses and manages device binding
3. **Swift LicenseService** - App-side license validation

## Part 1: Gumroad Setup

### 1. Create Your Product on Gumroad

1. Go to [Gumroad](https://gumroad.com) and sign up/log in
2. Click "New Product"
3. Set up your product:
   - **Name**: EchoText Pro
   - **Price**: $29 (launch price) / $59 (regular)
   - **Type**: Software license

### 2. Configure License Keys

1. In product settings, enable "Generate a unique license key per sale"
2. Note your **Product ID** (found in the product URL or API settings)

### 3. Create Launch Offer

For the "Founder's Edition" launch:
1. Create a discount code (e.g., `LAUNCH50` for 50% off)
2. Or set the initial price to $29 and plan to increase after 200 sales

## Part 2: Cloudflare Worker Setup

### 1. Prerequisites

```bash
# Install Wrangler CLI
npm install -g wrangler

# Login to Cloudflare
wrangler login
```

### 2. Deploy the Worker

```bash
cd cloudflare-worker

# Create KV namespace for license storage
wrangler kv:namespace create "LICENSE_KV"
# Copy the returned ID
```

### 3. Update Configuration

Edit `wrangler.toml` with your KV namespace ID:

```toml
[[kv_namespaces]]
binding = "LICENSE_KV"
id = "your-kv-namespace-id-here"
```

### 4. Set Gumroad Product ID

```bash
wrangler secret put GUMROAD_PRODUCT_ID
# Enter your Gumroad product ID when prompted
```

### 5. Deploy

```bash
wrangler deploy
```

Your worker will be available at:
`https://echotext-license-server.<your-subdomain>.workers.dev`

### 6. Test the Endpoints

```bash
# Health check
curl https://echotext-license-server.<your-subdomain>.workers.dev/health

# Test activation (will fail without valid key, but confirms API is working)
curl -X POST https://echotext-license-server.<your-subdomain>.workers.dev/activate \
  -H "Content-Type: application/json" \
  -d '{"license_key": "test", "machine_id": "test-machine"}'
```

## Part 3: Update App Configuration

### 1. Update Constants.swift

In `EchoText/Utilities/Constants.swift`, update:

```swift
enum License {
    static let serverURL = "https://echotext-license-server.<your-subdomain>.workers.dev"
    static let gumroadProductId = "<your-gumroad-product-id>"
}
```

### 2. Update Gumroad URL

In `Constants.swift`, update the Gumroad URL:

```swift
static let gumroadURL = URL(string: "https://<your-username>.gumroad.com/l/echotext")!
```

## Part 4: Feature Gating (Optional)

The system includes Pro feature definitions. To gate specific features:

```swift
// In any view or view model
if appState.isFeatureAvailable(.largeModels) {
    // Show large model options
} else {
    // Show upgrade prompt
}

// Quick check
if appState.isPro {
    // Pro user
}
```

### Pro Features Defined

| Feature | Description |
|---------|-------------|
| `.largeModels` | Large Whisper models (large, large-v3) |
| `.unlimitedRecording` | No time limits |
| `.autoInsert` | Auto-insert into apps |
| `.speakerDiarization` | Speaker identification |
| `.batchTranscription` | Batch file processing |
| `.watchFolder` | Folder monitoring |
| `.prioritySupport` | Priority email support |

## Part 5: Testing

### Test License Flow

1. **Build and run the app**
2. Go to **Settings → License**
3. Enter a test license key from Gumroad
4. Verify activation succeeds
5. Test on a second device to confirm "already activated" error

### Test Offline Mode

1. Activate license normally
2. Disconnect from internet
3. Relaunch app - should show "Pro (Offline Mode)"
4. After 7 days offline, license expires

## Pricing Strategy Summary

### Launch Pricing (Recommended)

| Tier | Price | Limit |
|------|-------|-------|
| Founder's Edition | $29 | First 200 customers |
| Regular Pro | $59 | After launch |
| Team 5 | $199 | 5 licenses |
| Team 10 | $349 | 10 licenses |

### Free vs Pro Features

| Feature | Free | Pro |
|---------|------|-----|
| Tiny/Base models | ✓ | ✓ |
| Small/Medium models | ✓ | ✓ |
| Large models | - | ✓ |
| Recording time | 5 min | Unlimited |
| Auto-insert | - | ✓ |
| Speaker diarization | - | ✓ |
| Batch transcription | - | ✓ |
| Watch folder | - | ✓ |

## Monitoring

### View Worker Logs

```bash
wrangler tail
```

### Check License Stats

You can query your KV namespace to see total activations:

```bash
wrangler kv:key list --namespace-id=<your-kv-id>
```

## Troubleshooting

### "Invalid license key"
- Verify the key exists in Gumroad
- Check that Product ID matches
- Ensure key hasn't been refunded

### "Already activated on another device"
- User needs to deactivate from the original device
- Or contact support to manually clear the binding

### Worker not responding
- Check `wrangler tail` for errors
- Verify KV namespace is bound correctly
- Check Gumroad API status

## Future: Auto-Updates (Sparkle)

To add auto-updates later:

1. Add Sparkle via SPM: `https://github.com/sparkle-project/Sparkle`
2. Create an appcast.xml file hosted on your server
3. Sign updates with EdDSA
4. Configure SUFeedURL in Info.plist

This is a separate implementation step when you're ready to ship updates.
