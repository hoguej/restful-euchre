#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "🚀 Starting September Sheds build process (simplified)..."

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

# Run database migrations (primary database only)
echo "🗃️ Running database migrations..."
bin/rails db:migrate

echo "✅ Build process completed successfully!" 