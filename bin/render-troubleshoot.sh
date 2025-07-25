#!/usr/bin/env bash
# Render Deployment Troubleshooting Script

echo "🔍 RENDER DEPLOYMENT TROUBLESHOOTING"
echo "===================================="
echo ""

echo "1. 📋 Current Render Configuration:"
echo "   - Main config: render.yaml"
echo "   - Simple config: render-simple.yaml"
echo ""

echo "2. 🔧 Build Script Status:"
if [ -x "bin/render-build.sh" ]; then
    echo "   ✅ bin/render-build.sh is executable"
else
    echo "   ❌ bin/render-build.sh is NOT executable"
fi

if [ -x "bin/render-build-simple.sh" ]; then
    echo "   ✅ bin/render-build-simple.sh is executable"
else
    echo "   ❌ bin/render-build-simple.sh is NOT executable"
fi

echo ""
echo "3. 🗃️ Migration Commands in Build Scripts:"
echo "   Main build script migrations:"
grep -n "db:migrate" bin/render-build.sh | sed 's/^/     /'
echo ""
echo "   Simple build script migrations:"
grep -n "db:migrate" bin/render-build-simple.sh | sed 's/^/     /'

echo ""
echo "4. 🚨 COMMON ISSUES & SOLUTIONS:"
echo ""
echo "   Issue A: Build script not configured in Render service"
echo "   Solution: In your Render dashboard, ensure Build Command is set to:"
echo "             './bin/render-build.sh' (for multi-database setup)"
echo "             './bin/render-build-simple.sh' (for single database setup)"
echo ""
echo "   Issue B: Migrations failing during build"
echo "   Solution: Check your Render build logs for migration errors"
echo ""
echo "   Issue C: Using manual deployment instead of automatic"
echo "   Solution: Make sure your Render service is connected to GitHub"
echo "             and auto-deploy is enabled"
echo ""
echo "   Issue D: Free plan limitations"
echo "   Solution: Consider upgrading to Starter plan ($7/month) to enable"
echo "             preDeployCommand for safer migration handling"
echo ""

echo "5. 🔧 RECOMMENDED ACTIONS:"
echo "   1. Check your Render service's Build Command setting"
echo "   2. Review recent build logs for migration errors"
echo "   3. Test build script locally: ./bin/render-build-simple.sh"
echo "   4. Consider enabling preDeployCommand on paid plan"
echo ""

echo "6. 📖 NEXT STEPS:"
echo "   - Log into your Render dashboard"
echo "   - Navigate to your september-sheds service"
echo "   - Check Settings > Build & Deploy"
echo "   - Verify Build Command matches your script"
echo "   - Review recent deployment logs"
echo ""

echo "✅ Troubleshooting complete!" 