# Repository Guidance

## Safety

- This repository manages a live home XCP-ng cluster and pfSense. Playbook targets are not tests: `make`, `make basics`, `make dns`, and `make vms` can change real hosts, DNS, or VMs. Do not run them merely to verify an edit.
- `make vms` has two distinct plays: `create` provisions VMs through OpenTofu, while `configure` changes existing VM CPU, memory, disk, GPU passthrough, autostart, and affinity. CPU/memory/disk changes only apply while a VM is stopped; GPU passthrough detection requires it running.
- Never print, decrypt, or commit secret material. `inventory/group_vars/all/vault.yml` is intentionally tracked and encrypted. `terraform/creds.tfvars` and `terraform/k8s.tfvars` are ignored generated files; `playbooks/vms.yml` overwrites them from `*.tfvars.j2` before provisioning.

## Tooling And Verification

- Use GNU Make 4+; the macOS system Make is rejected. The Make/runlist layer also requires `yq` and `jo`.
- Install the pinned controller dependencies with `uv sync --no-dev`; keep `pyproject.toml` and `requirements.txt` synchronized. Install collection versions with `ansible-galaxy install -r requirements.yml`. Ansible core must remain at 2.16.x because XCP-ng 8.3 targets Python 3.6.
- Run `make check` for syntax checks of the six top-level playbooks. Run `make lint` for the repository lint configuration, or `make lint -- basics` to lint one `playbooks/<name>.yml` file. Full lint also needs `jmespath` for `playbooks/awx.setup.yml`; it is not currently declared in the Python manifests.
- For OpenTofu edits, run `make tf -- fmt -check -recursive`. `make tf -- validate` requires prior initialization and the tracked `terraform/backend.config`; commands execute in the image built by `terraform/tf.sh`, not a host OpenTofu installation.
- There is no automated test suite or CI workflow. Prefer syntax/lint/format checks; do not substitute a live playbook run for missing tests.

## Execution Model

- `main.yml` defines the canonical playbook order and top-level tags: `python3`, `packages`, `basics`, `files`, `dns`, `vms`. Keep its first localhost play, including the `DO NOT REMOVE` marker, because it establishes `project_dir` for imported playbooks and shared paths.
- `make -- <ansible-options>` runs all plays; `make <tag>` selects plays; `make <tag>-` runs from that tag onward; `make -- -<tag>` runs through that tag. Prefix/suffix range syntax accepts exactly one tag. Options that take values must be passed as normal adjacent arguments, for example `make basics -- -l xcp1`.
- `scripts/play.sh` creates/updates `.venv`, installs dependencies on every live run, exports `ANSIBLE_CONFIG=./ansible.cfg` and `$HOME/.ssh/$USER.pem`, generates temporary `temp.yml`, and writes sanitized output to ignored `ansible.log`.
- `ansible.cfg` fixes inventory, Vault lookup, local collection paths, explicit fact gathering, and a one-day JSON fact cache under `.ansible/facts`. A full run purges cached facts; focused runs do not, so stale facts can affect behavior.
- Shared data lives in `vars/`; reusable included task files live in `tasks/`; executable plays live in `playbooks/`. VM definitions originate in `vars/vms.yml`; keep `host_affinities` and `vm_batches` aligned when changing VM placement.

## Infrastructure Details

- OpenTofu is rooted at `terraform/main.tf`; `terraform/modules/vm` owns Xen Orchestra VM creation and cloud-init. The wrapper mounts `terraform/`, `$HOME/.aws` read-only, and `${TMPDIR:-/tmp}` into Docker or Buildah, and logs planning/state commands to ignored `terraform/tf.log`/`tf.log.*` files.
- The S3 backend uses AWS profile `personal`. VM provisioning also requires reachable Xen Orchestra/XCP-ng services, the private local CA, the tagged shared Ubuntu autoinstall ISO, and `sshpass`; avoid `plan`, `apply`, or `destroy` unless explicitly requested.
- The Vault password helper supports macOS Keychain, an `age` key via `AGE_KEY_FILE`, or AWX. Do not modify its embedded encrypted payload as part of unrelated work.
