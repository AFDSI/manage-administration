#!/bin/bash
# Cross-platform consistency test script
# Run this on each platform to verify identical behavior

echo "Testing Cross-Platform Consistency"
echo "=================================="

# Test 1: Standard functions exist
echo "1. Testing standard functions..."
functions_to_test=("show_env" "check_versions" "show_commands" "amp" "projects")

for func in "${functions_to_test[@]}"; do
    if command -v "$func" >/dev/null 2>&1; then
        echo "✅ $func: Available"
    else
        echo "❌ $func: Missing"
    fi
done

echo ""

# Test 2: Environment variables
echo "2. Testing environment variables..."
required_vars=("HOME" "AMP_DEV_PROJECT" "NODE_OPTIONS")

for var in "${required_vars[@]}"; do
    if [ -n "${!var}" ]; then
        echo "✅ $var: Set"
    else
        echo "❌ $var: Not set"
    fi
done

echo ""

# Test 3: Directory structure
echo "3. Testing directory structure..."
dirs_to_check=("$HOME/projects" "$AMP_DEV_PROJECT")

for dir in "${dirs_to_check[@]}"; do
    if [ -d "$dir" ]; then
        echo "✅ Directory exists: $dir"
    else
        echo "❌ Directory missing: $dir"
    fi
done

echo ""

# Test 4: Security check
echo "4. Security validation..."
profile_files=(
    "$HOME/.bashrc.generated"
    "$HOME/.zshrc.generated" 
    "$HOME/profile.generated.ps1"
)

security_issues=0
for file in "${profile_files[@]}"; do
    if [ -f "$file" ]; then
        if grep -q "sk-[A-Za-z0-9]\{48\}" "$file" && ! grep -q "sk-your.*key" "$file"; then
            echo "🚨 SECURITY ISSUE: Hardcoded OpenAI key in $file"
            security_issues=$((security_issues + 1))
        elif grep -q "ghp_[A-Za-z0-9]\{36\}" "$file" && ! grep -q "ghp.*your.*token" "$file"; then
            echo "🚨 SECURITY ISSUE: Hardcoded GitHub token in $file"
            security_issues=$((security_issues + 1))
        else
            echo "✅ Security check passed: $file"
        fi
    fi
done

if [ $security_issues -eq 0 ]; then
    echo "✅ No security issues detected"
else
    echo "❌ $security_issues security issues found - regenerate profiles!"
fi

echo ""
echo "Consistency test complete"