# Erhhung's Home XCP-ng Cluster Configuration

This project manages the configuration and user files for Erhhung's XCP-ng cluster at home.

## Requirements

Since the XCP-ng cluster is currently on **XCP-ng version 8.2.1**, its underlying compatible Linux OS  
is **CentOS 7.5**, which only makes available **Python versions 2.7.5 and 3.6** _(not installed by default)_.

This necessitates the use of **ansible-core version < 2.17** (via `pip3 install "ansible < 10"`)  
_(see list of [Ansible releases](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-community-changelogs))_.

Create a **Python virtualenv** and install the Ansible packages:

```bash
cd ansible

python3 -m venv .venv
. .venv/bin/activate
pip3 install -r requirements.txt
```

Since XCP-ng is installed without private key authentication for SSH, Ansible requires the `sshpass`  
program to pass the `ansible_ssh_password` from Vault. Install via `brew install sshpass`.

## Connections

Store `ansible_ssh_password` in Ansible Vault:

```bash
export ANSIBLE_CONFIG=./ansible.cfg
VAULTFILE="group_vars/all/vault.yml"

ansible-vault create $VAULTFILE
ansible-vault edit   $VAULTFILE
```

The Ansible Vault password is stored in macOS Keychain under item "`XCP-ng`" for account "`ansible-vault`".

## Playbooks

Set the config variable first for the `ansible-playbook` commands below:

```bash
export ANSIBLE_CONFIG=./ansible.cfg
```

1. Install Python 3.6 on all hosts

    ```bash
    ansible-playbook python3.yml
    ```

2. Configure host and network settings

    2.1. **Host**: host name, time zone, locale and language  
    2.2. **Network**: DNS name servers and search domains

    ```bash
    ansible-playbook basics.yml
    ```

3. Set up admin user's home directory

    3.1. `~/isos` & `~/backups` symlinks  
    3.2. User dot files and README files

    ```bash
    ansible-playbook files.yml
    ```

Alternatively, **run all 3 playbooks** from the project root folder:

```bash
./play.sh
```
