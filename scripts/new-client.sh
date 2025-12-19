#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

bold(){ printf "\033[1m%s\033[0m\n" "$*"; }
ok(){ printf "✅ %s\n" "$*"; }
info(){ printf "ℹ️  %s\n" "$*"; }
warn(){ printf "⚠️  %s\n" "$*"; }
die(){ printf "❌ %s\n" "$*"; exit "${2:-2}"; }

command_exists(){ command -v "$1" >/dev/null 2>&1; }
validate_client(){ [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }

HOME_DIR="$HOME"
CLIENTS_ROOT="$HOME_DIR/workspace/clients"

SSH_DIR="$HOME_DIR/.ssh"
SSH_KEYS="$SSH_DIR/keys"
SSH_CONFIG="$SSH_DIR/config"

GIT_CLIENTS="$HOME_DIR/.config/git/clients"
GLOBAL_GITCONFIG="$HOME_DIR/.gitconfig"

MANAGED_BEGIN="# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>"
MANAGED_END="# <<< SAKURAJIMA MANAGED CLIENT HOSTS <<<"

USE_GITHUB=true
USE_GITLAB=true
USE_CLIPBOARD=true
USE_PASSPHRASE=true  # Default to secure (with passphrase)

CLIENT=""
USER_EMAIL=""
USER_NAME=""

usage(){
  cat <<EOF
new-client <client-name> [options]

Options:
  --github-only          Create only GitHub host alias
  --gitlab-only          Create only GitLab host alias
  --email <email>        Per-client git user.email
  --name <full-name>     Per-client git user.name
  --no-passphrase        Create SSH key WITHOUT passphrase (INSECURE - requires confirmation)
  --no-clipboard         Don't copy public key to clipboard

Client name must be kebab-case:
  e.g. bla-bla

NOTE: SSH keys are created WITH passphrases by default for security.
      Use --no-passphrase only for low-risk scenarios.
EOF
}

ensure_dir(){ mkdir -p "$1"; }
ensure_file(){ ensure_dir "$(dirname "$1")"; touch "$1"; }

ensure_trailing_newline() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if [[ -s "$file" ]]; then
    tail -c 1 "$file" | od -An -t u1 | grep -q ' 10' || printf "\n" >> "$file"
  fi
}

ensure_ssh_perms(){
  ensure_dir "$SSH_DIR" "$SSH_KEYS"
  ensure_file "$SSH_CONFIG"
  chmod 700 "$SSH_DIR" "$SSH_KEYS" || true
  chmod 600 "$SSH_CONFIG" || true
}

ensure_managed_block(){
  ensure_file "$SSH_CONFIG"
  ensure_trailing_newline "$SSH_CONFIG"

  if ! grep -Fqx "$MANAGED_BEGIN" "$SSH_CONFIG"; then
    {
      printf "\n%s\n" "$MANAGED_BEGIN"
      printf "%s\n" "$MANAGED_END"
    } >> "$SSH_CONFIG"
    ensure_trailing_newline "$SSH_CONFIG"
    ok "Initialized managed SSH block"
  fi

  grep -Fqx "$MANAGED_END" "$SSH_CONFIG" || die "SSH managed block malformed (missing end marker)" 3
}

insert_ssh_block_if_missing(){
  local unique="$1"
  local block="$2"

  ensure_managed_block
  ensure_trailing_newline "$SSH_CONFIG"

  if grep -Fq "$unique" "$SSH_CONFIG"; then
    ok "SSH entry exists: $unique"
    return 0
  fi

  local tmp; tmp="$(mktemp)"
  local tmp_block; tmp_block="$(mktemp)"

  # Cleanup trap for temp files (function scope)
  trap 'rm -f "$tmp" "$tmp_block"' RETURN

  echo "$block" > "$tmp_block"

  awk -v end="$MANAGED_END" -v blockfile="$tmp_block" '
    $0==end { while ((getline line < blockfile) > 0) print line; close(blockfile); print $0; next }
    { print }
  ' "$SSH_CONFIG" > "$tmp"

  mv "$tmp" "$SSH_CONFIG"

  ensure_trailing_newline "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG" || true
  ok "Added SSH entry: $unique"
}

ensure_git_includeif(){
  local client="$1"
  local include_path="~/.config/git/clients/${client}.gitconfig"
  local gitdir="gitdir:~/workspace/clients/${client}/"

  ensure_file "$GLOBAL_GITCONFIG"

  if grep -Fq "[includeIf \"${gitdir}\"]" "$GLOBAL_GITCONFIG"; then
    if grep -Fq "path = ${include_path}" "$GLOBAL_GITCONFIG"; then
      ok "Git includeIf exists for $client"
      return 0
    fi
    die "Git includeIf exists but path differs. Fix manually." 3
  fi

  {
    printf "\n[includeIf \"%s\"]\n" "$gitdir"
    printf "    path = %s\n" "$include_path"
  } >> "$GLOBAL_GITCONFIG"

  ok "Added git includeIf for $client"
}

create_client_gitconfig(){
  local client="$1"
  local file="$GIT_CLIENTS/${client}.gitconfig"

  ensure_dir "$GIT_CLIENTS"

  if [[ -f "$file" ]]; then
    ok "Client gitconfig exists: $file"
    return 0
  fi

  {
    printf "[user]\n"
    printf "    name = %s\n" "${USER_NAME:-Dev}"
    printf "    email = %s\n" "${USER_EMAIL:-dev@${client}.local}\n"
    printf "\n[commit]\n"
    printf "    gpgsign = false\n"
  } > "$file"

  ok "Created: $file"
}

generate_ssh_key(){
  local key="$1"
  local comment="$2"

  if [[ -f "$key" && -f "${key}.pub" ]]; then
    ok "SSH key exists: $key"
    return 0
  fi

  if $USE_PASSPHRASE; then
    info "Creating SSH key with passphrase (secure default)"
    ssh-keygen -t ed25519 -C "$comment" -f "$key"
  else
    warn "Creating SSH key WITHOUT passphrase (INSECURE)"
    warn "If your machine is compromised, all client SSH access will be exposed!"
    read -p "Are you sure you want to proceed? (yes/N) " -r
    if [[ "$REPLY" != "yes" ]]; then
      die "Aborted. Remove --no-passphrase flag for secure key generation." 2
    fi
    ssh-keygen -t ed25519 -C "$comment" -f "$key" -N ""
  fi

  chmod 600 "$key" || true
  chmod 644 "${key}.pub" || true
  ok "Generated SSH key: $key"
}

copy_pubkey(){
  local pub="$1"
  $USE_CLIPBOARD || { warn "Clipboard disabled"; return 0; }

  if command_exists pbcopy; then
    pbcopy < "$pub"
    ok "Public key copied to clipboard"
  else
    warn "pbcopy not available; skipping clipboard"
  fi
}

[[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 2; }

CLIENT="$1"; shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-only) USE_GITHUB=true; USE_GITLAB=false; shift ;;
    --gitlab-only) USE_GITHUB=false; USE_GITLAB=true; shift ;;
    --email) [[ -n "${2:-}" ]] || die "--email requires value" 2; USER_EMAIL="$2"; shift 2 ;;
    --name)  [[ -n "${2:-}" ]] || die "--name requires value" 2; USER_NAME="$2"; shift 2 ;;
    --no-passphrase) USE_PASSPHRASE=false; shift ;;
    --no-clipboard) USE_CLIPBOARD=false; shift ;;
    *) die "Unknown option: $1" 2 ;;
  esac
done

validate_client "$CLIENT" || die "Invalid client name: $CLIENT (kebab-case required)" 2
command_exists ssh-keygen || die "ssh-keygen missing" 3

bold "🏗  Provisioning client: $CLIENT"

ensure_dir "$CLIENTS_ROOT/$CLIENT"
ok "Workspace ready: $CLIENTS_ROOT/$CLIENT"

ensure_ssh_perms

KEY="$SSH_KEYS/gh-${CLIENT}_ed25519"
generate_ssh_key "$KEY" "dev@${CLIENT}"

create_client_gitconfig "$CLIENT"
ensure_git_includeif "$CLIENT"

if $USE_GITHUB; then
  insert_ssh_block_if_missing "Host github-${CLIENT}" \
"Host github-${CLIENT}
    HostName github.com
    User git
    IdentityFile ${KEY}
    IdentitiesOnly yes
"
fi

if $USE_GITLAB; then
  insert_ssh_block_if_missing "Host gitlab-${CLIENT}" \
"Host gitlab-${CLIENT}
    HostName gitlab.com
    User git
    IdentityFile ${KEY}
    IdentitiesOnly yes
"
fi

copy_pubkey "${KEY}.pub"

echo
bold "✅ DONE"
info "Client dir:   $CLIENTS_ROOT/$CLIENT"
info "SSH key:      $KEY"
info "Git config:   $GIT_CLIENTS/${CLIENT}.gitconfig"
echo
info "Public key:"
cat "${KEY}.pub"
