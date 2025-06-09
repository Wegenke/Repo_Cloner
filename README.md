# Repo Cloner

The primary focus of this script is to clone multiple Git repositories in one fell swoop.

A simple, flexible Bash script that clones multiple Git repositories to the same parent directory. By default, the script reads links from `repo_list.txt`, formats them for SSH key usage, and clones them to the current working directory. Use the flags below to customize the behavior.

---

## Flags

| Flag                          | Description                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------- |
| `--HTTPS`, `-H`               | Sets clone URL prefix to `https://` (default: `git@` for SSH)                   |
| `--destination=DIR`, `-d=DIR` | Directory to clone repositories into (default: current directory)               |
| `--repo-list=FILE`, `-r=FILE` | Path to the `.txt` file containing repository URLs (default: `./repo_list.txt`) |
| `--sequential`, `-s`          | Clone repositories one at a time (instead of in parallel)                       |
| `--dry-run`, `-p`             | Simulate the process without cloning or creating directories                    |
| `--help`, `-h`                | Show this help message and exit                                                 |

---

## Examples

```bash
./repo_cloner.sh --HTTPS
./repo_cloner.sh --destination=./clones --repo-list=./my-repos.txt
./repo_cloner.sh --sequential --destination=./test-clone
./repo_cloner.sh -s -H -d=./test-clone
./repo_cloner.sh -p -d=./test-dir
```

---

## Features

* Reads a list of Git repo URLs from a `.txt` file (default: `repo_list.txt`)
* Supports both SSH and HTTPS cloning
* Clones in parallel for speed (or sequentially if desired)
* Fully customizable via flags:

  * `--sequential` / `-s` — reduces resource usage
  * `--destination` / `-d` — specify where to place cloned repos
  * `--repo-list` / `-r` — provide a custom `.txt` file to read from
  * `--dry-run` / `-p` — preview the result without cloning or writing
  * `--help` / `-h` — see usage and examples
* Supports public and private repositories using SSH keys
* Displays a clean spinner while cloning
* Summarizes successes and failures
* Automatically cleans up temp files

---

## Setup

### 1. Clone or download the script

Place the following two files in a directory:

* `repo_cloner.sh` — the script
* `repo_list.txt` — a file containing one Git repo URL per line

Example `repo_list.txt`:

```text
# Public Repos
https://github.com/octocat/hello-world.git
git@github.com:yourusername/your-private-repo.git
```

> You can mix and match HTTPS and SSH URLs!

---

## Usage

### Default (clones into current directory):

```bash
./repo_cloner.sh
```

### With a custom output directory:

```bash
./repo_cloner.sh --destination=./my-dir
```

If the directory doesn’t exist, the script will create it for you.

---

## Output Example

```text
Directory does not exist. Creating: ./home
Directory created successfully.
Cloning complete.

================ Clone Summary ================
Successful: 5
  - user1-repo1
  - user2-repo2
Failed: 1
  - https://github.com/invalid/repo.git
===============================================
```

---

## Spinner Function Explained

The spinner provides visual feedback while repos are being cloned in parallel.

### How it works:

* Background jobs are forked for each clone
* The `spinner()` function loops through characters (`|`, `/`, `-`, `\`)
* It checks whether background processes are still running using `kill -0`
* Once all are finished, it prints "Cloning complete."

---

