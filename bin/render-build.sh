#!/usr/bin/env bash
# Exit on error
set -o errexit

echo "🚀 Starting September Sheds build process..."

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

# Run database migrations for all databases
echo "🗃️ Running database migrations..."
bin/rails db:migrate

echo "🗄️ Running cache database migrations..."
bin/rails db:migrate:cache

echo "📬 Running queue database migrations..."
bin/rails db:migrate:queue

echo "📡 Running cable database migrations..."
bin/rails db:migrate:cable

echo "✅ Build process completed successfully!" 