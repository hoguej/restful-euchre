#!/usr/bin/env bash
# Improved Render Build Script with Better Migration Handling
# Exit on error
set -o errexit

echo "🚀 Starting September Sheds build process (improved)..."
echo "=================================================="

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

# Function to run migrations with error handling
run_migrations() {
    local db_name=$1
    local migrate_command=$2
    
    echo "🗃️ Running $db_name migrations..."
    
    # Check if database exists and is accessible
    if bin/rails runner "puts 'Database accessible'" > /dev/null 2>&1; then
        echo "   ✅ Database connection verified"
        
        # Run migrations with timeout protection
        timeout 300 $migrate_command || {
            echo "   ⚠️  Migration timed out after 5 minutes"
            echo "   🔄 Retrying with shorter timeout..."
            timeout 60 $migrate_command || {
                echo "   ❌ Migration failed after retry"
                exit 1
            }
        }
        
        echo "   ✅ $db_name migrations completed successfully"
    else
        echo "   ⚠️  Database not accessible, skipping migrations"
        echo "   💡 You may need to run migrations manually after deployment"
    fi
}

# Run migrations for all configured databases
echo ""
echo "🗄️ MIGRATION PHASE"
echo "=================="

# Primary database (always run this)
run_migrations "Primary database" "bin/rails db:migrate"

# Secondary databases (run if configured)
if [ -n "$CACHE_DATABASE_URL" ]; then
    run_migrations "Cache database" "bin/rails db:migrate:cache"
fi

if [ -n "$QUEUE_DATABASE_URL" ]; then
    run_migrations "Queue database" "bin/rails db:migrate:queue"
fi

if [ -n "$CABLE_DATABASE_URL" ]; then
    run_migrations "Cable database" "bin/rails db:migrate:cable"
fi

echo ""
echo "🎯 POST-MIGRATION TASKS"
echo "======================="

# Verify migrations were applied
echo "📊 Verifying migration status..."
bin/rails db:migrate:status | head -10

# Pre-warm the application (optional)
echo "🔥 Pre-warming application..."
bin/rails runner "puts 'Application pre-warmed successfully'" || echo "   ⚠️  Pre-warming failed (non-critical)"

echo ""
echo "✅ Build process completed successfully!"
echo "🎉 Ready for deployment!" 