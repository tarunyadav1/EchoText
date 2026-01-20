#!/bin/bash

# EchoText License Server - Setup Script
# Run this once to set up the Cloudflare Worker

set -e

echo "🚀 EchoText License Server Setup"
echo "================================="
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "📦 Installing Wrangler CLI..."
    npm install -g wrangler
fi

# Check if logged in
echo "🔐 Checking Cloudflare login..."
if ! wrangler whoami &> /dev/null; then
    echo "Please login to Cloudflare:"
    wrangler login
fi

echo ""
echo "✅ Logged in to Cloudflare"
echo ""

# Create KV namespace
echo "📁 Creating KV namespace for license storage..."
KV_OUTPUT=$(wrangler kv:namespace create "LICENSE_KV" 2>&1) || true

if echo "$KV_OUTPUT" | grep -q "already exists"; then
    echo "⚠️  KV namespace already exists"
    echo "   If you need the ID, run: wrangler kv:namespace list"
else
    echo "$KV_OUTPUT"
    echo ""
    echo "⚠️  IMPORTANT: Copy the 'id' value above and update wrangler.toml"
fi

echo ""
echo "📝 Next steps:"
echo ""
echo "1. Update wrangler.toml with your KV namespace ID"
echo ""
echo "2. Set your Gumroad product ID:"
echo "   wrangler secret put GUMROAD_PRODUCT_ID"
echo ""
echo "3. For GitHub auto-deploy, add these secrets to your repo:"
echo "   - CLOUDFLARE_API_TOKEN"
echo "   - CLOUDFLARE_ACCOUNT_ID"
echo ""
echo "4. Or deploy manually:"
echo "   wrangler deploy"
echo ""
echo "🎉 Setup complete!"
