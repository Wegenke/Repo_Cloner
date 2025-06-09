#!/bin/bash

# Default values
REPOS="./repo_list.txt"
REPOS_DEST="."
SEQUENTIAL=false
DRY_RUN=false
CLONE_PREFIX="git@"

# Help message function
show_help() {
  cat <<EOF
Usage: $0 [--destination=DIR] [--repo-list=FILE] [--sequential] [--help]

Options:
  --HTTPS, -H                       Sets clone line to https:// (default: git@ (using ssh-key))
  --destination=DIR, -d=Directory   Directory to clone repositories into (default: current directory)
  --repo-list=FILE, -r=FILE         Path to the file containing list of repos (default: ./repo_list.txt)
  --sequential, -s                  Clone repositories one at a time (sequentially)
  --help, -h                        Show this help message and exit
  --dry-run, -p                     Simulate actions without cloning (preview mode)

Examples:
  $0 --destination=./clones --repo-list=./my-repos.txt
  $0 --destination=./clones -r=./my-repos.txt
  $0 --sequential --destination=./test-clone 
  $0 -s -t -d=./test-clone 
  $0 -t -d./test-dir
EOF
}

# Parse command-line arguments
for arg in "$@"; do
  case $arg in
  --destination=* | -d=*)
    REPOS_DEST="${arg#*=}"
    ;;
  --repo-list=* | -r=*)
    REPOS="${arg#*=}"
    ;;
  --HTTPS | -H)
    CLONE_PREFIX="https://"
    ;;
  --sequential | -s)
    SEQUENTIAL=true
    ;;
  --dry-run | -p)
    DRY_RUN=true
    ;;
  --help | -h)
    show_help
    exit 0
    ;;
  *)
    echo "Unknown option: $arg"
    echo "Use --help to see valid options."
    exit 1
    ;;
  esac
done

# Check if directory exists or create it
if $DRY_RUN; then
  echo "[DRY RUN] Would create $REPOS_DEST"
  echo "$REPOS_DEST creating success?"
elif [[ -d "$REPOS_DEST" ]]; then
  echo "Clone destination : $REPOS_DEST"
else
  echo "Directory does not exist. Creating: $REPOS_DEST"
  if mkdir -p "$REPOS_DEST"; then
    echo "Directory created successfully."
  else
    echo "Failed to create directory: $REPOS_DEST"
    exit 1
  fi
fi

# Temp files for safe inter-process communication
SUCCESS_TEMP=$(mktemp)
FAIL_TEMP=$(mktemp)

# Ensure cleanup on script exit
cleanup() {
  rm -f "$SUCCESS_TEMP" "$FAIL_TEMP"
}
trap cleanup EXIT

# Function to clone a repo and record result
clone_repo() {
  local repo="$1"
  local username="$2"
  local reponame="$3"
  local target="${REPOS_DEST}/${username}-${reponame}"

  if $DRY_RUN; then
    echo "[DRY RUN] Would clone $repo into $target"
    echo "${username}-${reponame}" >>"$SUCCESS_TEMP"
  elif git clone "$repo" "$target" >/dev/null 2>&1; then
    echo "${username}-${reponame}" >>"$SUCCESS_TEMP"
  else
    echo "$repo" >>"$FAIL_TEMP"
  fi
}

# Function to normalize the url based on HTTPS flag
normalize_repo_url() {
  local raw_url="$1"
  local user_repo=$(echo "$raw_url" | sed -E 's#(https://github\.com/|git@github\.com:)##')

  if [[ "$CLONE_PREFIX" == git@* ]]; then
    echo "${CLONE_PREFIX}github.com:${user_repo}" # SSH format
  else
    echo "${CLONE_PREFIX}github.com/${user_repo}" # HTTPS format
  fi
}

# Check if repo list exists
if [[ ! -f "$REPOS" ]]; then
  echo "Repo list file not found: $REPOS"
  exit 1
fi

# Prepare background process tracking
pids=()

# Process each repo URL
while IFS= read -r repo || [[ -n "$repo" ]]; do
  repo="$(echo "$repo" | xargs)"                 # Trim leading/trailing whitespace
  [[ -z "$repo" || "$repo" == \#* ]] && continue # Skip empty or comment lines

  # Normalize repo URL to match prefix style
  if [[ "$repo" =~ ^https://github\.com/ || "$repo" =~ ^git@github\.com: ]]; then
    repo=$(normalize_repo_url "$repo")
  fi

  # Extract username and repo name
  IFS='/' read -ra parts <<<"${repo//:/\/}" 
  if [[ ${#parts[@]} -lt 2 ]]; then
    echo "Warning: Skipping malformed repo URL: $repo"
    echo "$repo" >>"$FAIL_TEMP"
    continue
  fi

  username="${parts[-2]}"
  reponame=$(basename "$repo" .git)

  if $SEQUENTIAL; then
    echo "Cloning $username/$reponame..."
    clone_repo "$repo" "$username" "$reponame"
  else
    clone_repo "$repo" "$username" "$reponame" &
    pids+=($!)
  fi
done <"$REPOS"

# Spinner function
spinner() {
  local delay=0.1
  local spinstr='|/-\'
  while true; do
    all_done=true
    for pid in "${pids[@]}"; do
      if kill -0 "$pid" 2>/dev/null; then
        all_done=false
        break
      fi
    done

    if $all_done; then
      break
    fi

    local temp=${spinstr#?}
    printf "\rCloning repositories... [%c]" "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  printf "\rCloning complete.                \n"
}

# Wait for background jobs if running in parallel
if ! $SEQUENTIAL && [[ ${#pids[@]} -gt 0 ]]; then
  spinner
  wait
fi

# Load results from temp files
success_list=()
fail_list=()
success_count=0
fail_count=0

if [[ -f "$SUCCESS_TEMP" ]]; then
  mapfile -t success_list <"$SUCCESS_TEMP"
  success_count=${#success_list[@]}
fi

if [[ -f "$FAIL_TEMP" ]]; then
  mapfile -t fail_list <"$FAIL_TEMP"
  fail_count=${#fail_list[@]}
fi

# Summary
echo ""
echo "================ Clone Summary ================"
echo "Successful: $success_count"
for repo in "${success_list[@]}"; do
  echo "  - $repo"
done

if [[ $fail_count -gt 0 ]]; then
  echo ""
  echo "Failed: $fail_count"
  for repo in "${fail_list[@]}"; do
    echo "  - $repo"
  done
fi
echo "==============================================="

if $DRY_RUN; then
  echo ""
  echo "Dry run complete. No repositories were actually cloned."
fi
