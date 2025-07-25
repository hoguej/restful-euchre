#!/usr/bin/env bash
# Render Build Script (No Migrations) - For Paid Plans with preDeployCommand
# Exit on error
set -o errexit

echo "🚀 Starting September Sheds build process (no migrations)..."
echo "=========================================================="

# Install dependencies (excluding development/test gems for production)
echo "📦 Installing Ruby gems..."
if [ "$RAILS_ENV" = "production" ]; then
    bundle config set --local without 'development test'
fi
bundle install

# Precompile assets
echo "🎨 Precompiling assets..."
bin/rails assets:precompile

# Clean old assets
echo "🧹 Cleaning old assets..."
bin/rails assets:clean

# Verify build completed successfully
echo "🔍 Verifying build..."
if [ -d "public/assets" ]; then
    echo "   ✅ Assets compiled successfully"
else
    echo "   ❌ Assets compilation failed"
    exit 1
fi

echo ""
echo "✅ Build process completed successfully!"
echo "💡 Migrations will run in preDeployCommand phase" 