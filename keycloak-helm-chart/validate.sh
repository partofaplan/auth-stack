#!/bin/bash

# Keycloak Helm Chart Validation Script
# This script validates the Helm chart configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Keycloak Helm Chart Validator        ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo ""

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name=$1
    local test_command=$2

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $test_name... "

    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "1. Validating Chart Structure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Chart.yaml exists" "test -f Chart.yaml"
run_test "values.yaml exists" "test -f values.yaml"
run_test "templates directory exists" "test -d templates"
run_test "_helpers.tpl exists" "test -f templates/_helpers.tpl"
run_test "NOTES.txt exists" "test -f NOTES.txt"

echo ""
echo "2. Validating Helm Syntax"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Helm lint (default values)" "helm lint ."
run_test "Helm lint (production values)" "helm lint . -f values-production.yaml"
run_test "Helm lint (rancher values)" "helm lint . -f values-rancher.yaml"

echo ""
echo "3. Validating Template Rendering"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Template rendering (default)" "helm template test . --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"
run_test "Template rendering (production)" "helm template test . -f values-production.yaml --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"
run_test "Template rendering (rancher)" "helm template test . -f values-rancher.yaml --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"

echo ""
echo "4. Validating Kubernetes Manifests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Generate manifests for validation
helm template test . \
    --set keycloak.auth.adminPassword=test \
    --set postgresql.auth.password=test \
    > /tmp/keycloak-manifests.yaml

run_test "YAML syntax validation" "kubectl apply --dry-run=client -f /tmp/keycloak-manifests.yaml > /dev/null"
run_test "StatefulSet generated" "grep -q 'kind: StatefulSet' /tmp/keycloak-manifests.yaml"
run_test "Service generated" "grep -q 'kind: Service' /tmp/keycloak-manifests.yaml"
run_test "Ingress generated" "grep -q 'kind: Ingress' /tmp/keycloak-manifests.yaml"
run_test "ServiceAccount generated" "grep -q 'kind: ServiceAccount' /tmp/keycloak-manifests.yaml"

echo ""
echo "5. Validating Template Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "StatefulSet template exists" "test -f templates/statefulset.yaml"
run_test "Service template exists" "test -f templates/service.yaml"
run_test "Ingress template exists" "test -f templates/ingress.yaml"
run_test "ConfigMap template exists" "test -f templates/configmap.yaml"
run_test "Secret template exists" "test -f templates/secret.yaml"
run_test "ServiceAccount template exists" "test -f templates/serviceaccount.yaml"
run_test "RBAC template exists" "test -f templates/rbac.yaml"
run_test "ServiceMonitor template exists" "test -f templates/servicemonitor.yaml"
run_test "PodDisruptionBudget template exists" "test -f templates/poddisruptionbudget.yaml"

echo ""
echo "6. Validating Values Files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "values.yaml is valid YAML" "python3 -c 'import yaml; yaml.safe_load(open(\"values.yaml\"))' 2>/dev/null || ruby -ryaml -e 'YAML.load_file(\"values.yaml\")' 2>/dev/null"
run_test "values-production.yaml is valid YAML" "python3 -c 'import yaml; yaml.safe_load(open(\"values-production.yaml\"))' 2>/dev/null || ruby -ryaml -e 'YAML.load_file(\"values-production.yaml\")' 2>/dev/null"
run_test "values-rancher.yaml is valid YAML" "python3 -c 'import yaml; yaml.safe_load(open(\"values-rancher.yaml\"))' 2>/dev/null || ruby -ryaml -e 'YAML.load_file(\"values-rancher.yaml\")' 2>/dev/null"

echo ""
echo "7. Validating Dependencies"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Chart.yaml has dependencies" "grep -q 'dependencies:' Chart.yaml"
run_test "PostgreSQL dependency defined" "grep -q 'name: postgresql' Chart.yaml"

echo ""
echo "8. Advanced Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test with different replica counts
run_test "Render with 1 replica" "helm template test . --set keycloak.replicas=1 --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"
run_test "Render with 3 replicas" "helm template test . --set keycloak.replicas=3 --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"

# Test with ingress disabled
run_test "Render with ingress disabled" "helm template test . --set ingress.enabled=false --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"

# Test with PostgreSQL disabled
run_test "Render with external DB" "helm template test . --set postgresql.enabled=false --set keycloak.configuration.database.hostname=external-db --set keycloak.configuration.database.password=test --set keycloak.auth.adminPassword=test > /dev/null"

# Test with autoscaling
run_test "Render with autoscaling" "helm template test . --set autoscaling.enabled=true --set keycloak.auth.adminPassword=test --set postgresql.auth.password=test > /dev/null"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    echo -e "${RED}❌ Validation FAILED${NC}"
    exit 1
else
    echo -e "Tests Failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}✅ All validations PASSED!${NC}"
    echo ""
    echo "The Helm chart is ready for deployment."
    echo ""
    echo "Next steps:"
    echo "  1. Update dependencies: helm dependency update"
    echo "  2. Install the chart: ./install.sh"
    echo "  3. Or deploy manually: helm install keycloak . -n keycloak"
fi

# Cleanup
rm -f /tmp/keycloak-manifests.yaml

echo ""
