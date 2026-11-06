#!/usr/bin/env bash
# Checks which commands the agent-team deploy hook gates. Run from the repo root.

hook="plugins/agent-team/hooks/confirm-deploy.sh"
failures=0

check() {
  local expected=$1 cmd=$2 out actual
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd" | "$hook")
  actual=allow
  [ -n "$out" ] && actual=ask
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: expected $expected, got $actual: $cmd"
    failures=$((failures + 1))
  fi
}

check ask   'kubectl -n prod apply -f k8s/'
check ask   'kubectl rollout undo deployment/api'
check ask   'terraform -chdir=infra apply -auto-approve'
check ask   'helm upgrade api ./chart'
check ask   'helm rollback api 3'
check ask   'gcloud run deploy api --image img'
check ask   'aws ecs update-service --cluster c --service s'
check ask   'npm test && docker push repo/img:1'
check ask   './scripts/deploy-prod.sh'
check ask   'vercel --prod'

check allow 'terraform plan'
check allow 'kubectl get pods -n prod'
check allow 'kubectl logs api-123 | grep error'
check allow 'helm history api'
check allow 'aws s3 ls'
check allow 'ls deployments/'
check allow 'cat deploy.md'

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
