# Erhhung's Home XCP-ng Cluster Configuration

This project manages the configuration and user files for Erhhung's XCP-ng cluster at home.

## Requirements

Since the XCP-ng cluster is currently on **XCP-ng version 8.2.1**, its underlying compatible Linux OS  
is **CentOS 7.5**, which only makes available **Python versions 2.7.5 and 3.6** _(not installed by default)_.

This necessitates the use of **ansible-core version < 2.17** (via `pip3 install "ansible < 10"`)  
_(see list of [Ansible releases](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs))_.

Create a **Python virtualenv** and install the Ansible packages
(using [uv](https://docs.astral.sh/uv/) is highly recommended):

```bash
python3 -m venv .venv # or `uv venv`
. .venv/bin/activate

pip3 install -U pip
# pyproject.toml should be kept in-sync with requirements.txt
pip3 install -r requirements.txt # or `uv sync`
```

Since XCP-ng is installed without private key authentication for SSH, Ansible requires the `sshpass`  
program to pass the `ansible_ssh_password` from Vault. Install via `brew install sshpass`.

## Ansible Vault

The Ansible Vault password is stored in macOS Keychain under item "`XCP-ng`" for account "`ansible-vault`".

```bash
export ANSIBLE_CONFIG=./ansible.cfg
VAULTFILE="group_vars/all/vault.yml"

ansible-vault create $VAULTFILE
ansible-vault edit   $VAULTFILE
```

Variables stored in Ansible Vault:

* `ansible_ssh_password`

## Playbooks

Set the config variable first for the `ansible-playbook` commands below:

```bash
export ANSIBLE_CONFIG=./ansible.cfg
```

1. Install Python 3.6 on all hosts

    ```bash
    ansible-playbook python3.yml
    ```

2. Install extra packages into dom0

    **WARNING!** Be very careful with installing non-critical cruft into `dom0`!  
    **Read the [rules](https://docs.xcp-ng.org/management/additional-packages/#-rules) first!**

    ```bash
    ansible-playbook packages.yml
    ```

3. Configure host and network settings

    3.1. **Host**: host name, time zone, locale and language  
    3.2. **Network**: DNS name servers and search domains

    ```bash
    ansible-playbook basics.yml
    ```

4. Set up admin user's home directory

    4.1. `~/isos` & `~/backups` symlinks  
    4.2. User dot files and README files

    ```bash
    ansible-playbook files.yml
    ```

Alternatively, **run all playbooks** automatically in order:

```bash
# pass options like -v and --step
./play.sh [ansible-playbook-opts]
```

Output from `play.sh` will be logged in "`ansible.log`".

## Troubleshooting

* If you encounter the following error, it means you're not using ansible-core version < 2.17.  
  Make sure you follow the [Requirements](#Requirements) and install Ansible in a Python virtual environment.

    ```
    SyntaxError: future feature annotations is not defined
    ```

* Ansible's [ad-hoc commands](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html#managing-services) are useful in these scenarios.
  For example:

    ```bash
    ansible xcphosts -m ansible.builtin.raw -b -a "yum update"
    ```
