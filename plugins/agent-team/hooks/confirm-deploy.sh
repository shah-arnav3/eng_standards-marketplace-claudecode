#!/usr/bin/env bash
# PreToolUse hook: forces a permission prompt for Bash commands that deploy,
# roll back, or mutate live infrastructure. The agent prompts already forbid
# unapproved deploys; this enforces it even when a prompt is ignored.
# Matching is deliberately broad: a false positive costs one extra prompt.

input=$(cat)

# Pull tool_input.command out of the JSON payload without depending on jq.
cmd=$(printf '%s' "$input" | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p')
[ -z "$cmd" ] && cmd=$input

# [^|;&]* lets flags sit between the tool and its subcommand (kubectl -n prod apply)
# without matching across a pipe or command separator.
gap='[^|;&]*'
patterns=(
  "(terraform|tofu)${gap}[[:space:]](apply|destroy|import|state[[:space:]]+(rm|mv|push))"
  "kubectl${gap}[[:space:]](apply|create|delete|replace|patch|scale|drain|rollout[[:space:]]+(undo|restart)|set[[:space:]]+image)"
  "helm${gap}[[:space:]](install|upgrade|rollback|uninstall|delete)"
  "pulumi${gap}[[:space:]](up|destroy)"
  "(cdk|sam|serverless|sls)${gap}[[:space:]](deploy|destroy|remove)"
  "aws${gap}[[:space:]](cloudformation[[:space:]]+(deploy|create-stack|update-stack|delete-stack)|ecs[[:space:]]+update-service|lambda[[:space:]]+update-function-code|deploy[[:space:]]+create-deployment)"
  "az${gap}[[:space:]](deployment${gap}[[:space:]]create|webapp[[:space:]]+deploy|containerapp[[:space:]]+update|functionapp[[:space:]]+deployment)"
  "gcloud${gap}[[:space:]](deploy|rollback|releases[[:space:]]+promote)"
  "argocd${gap}[[:space:]]app[[:space:]]+(sync|rollback|delete)"
  "(flyctl|fly)${gap}[[:space:]]deploy"
  "(vercel|netlify)${gap}--prod"
  "docker${gap}[[:space:]]push"
  "make${gap}[[:space:]](deploy|release|rollback)"
  "(^|[[:space:]/])(deploy|rollback|release)[-_[:alnum:]]*\.(sh|py)"
)

for pattern in "${patterns[@]}"; do
  if printf '%s' "$cmd" | grep -Eq "$pattern"; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"agent-team: this command deploys, rolls back, or changes live infrastructure. Approve only if you intend it to run now."}}\n'
    exit 0
  fi
done

exit 0
