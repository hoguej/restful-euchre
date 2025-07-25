#!/usr/bin/env bash
# Render Migration Script - Runs in preDeployCommand phase
# Exit on error
set -o errexit

echo "🗃️ Starting September Sheds migration process..."
echo "==============================================="

# Function to run migrations with error handling
run_migrations() {
    local db_name=$1
    local migrate_command=$2
    
    echo "🔄 Running $db_name migrations..."
    
    # Check if database exists and is accessible
    if timeout 30 $migrate_command --dry-run > /dev/null 2>&1; then
        echo "   ✅ Database connection verified"
        
        # Run actual migrations
        $migrate_command
        
        echo "   ✅ $db_name migrations completed successfully"
    else
        echo "   ❌ Database not accessible or migration failed"
        echo "   💡 Check database configuration and connectivity"
        exit 1
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
echo "📊 MIGRATION VERIFICATION"
echo "========================"

# Verify migrations were applied
echo "🔍 Checking migration status..."
bin/rails db:migrate:status | head -5

# Check for pending migrations
pending_migrations=$(bin/rails db:migrate:status | grep -c "   down   " || echo "0")
if [ "$pending_migrations" -gt 0 ]; then
    echo "   ⚠️  Warning: $pending_migrations pending migrations found"
else
    echo "   ✅ All migrations are up to date"
fi

echo ""
echo "✅ Migration process completed successfully!"
echo "🎉 Ready for deployment!" 