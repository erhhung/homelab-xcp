# Erhhung's Home XCP-ng Cluster Configuration

This project manages the configuration and user files for Erhhung's XCP-ng cluster at home.

## Requirements

Since the XCP-ng cluster version is currently **8.3**, its underlying compatible Linux OS is **CentOS 7.5**,  
which only makes available Python versions **2.7.5** and **3.6** _(installed by default on 8.3 and later only)_.

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
program to pass the `ansible_ssh_password` from Vault. Install by running `brew install sshpass`.

## Ansible Vault

The Ansible Vault password is stored in macOS Keychain under item `XCP-ng` for account `ansible-vault`.

```bash
export ANSIBLE_CONFIG="./ansible.cfg"
VAULTFILE="inventory/group_vars/all/vault.yml"

ansible-vault create $VAULTFILE
ansible-vault edit   $VAULTFILE
ansible-vault view   $VAULTFILE
```

Variables protected by Ansible Vault:

- `xcpng_root_pass`
- `xoa_admin_pass`
- `pfsense_api_key`

## Playbooks

1. Install Python 3.6 on all hosts

    ```bash
    make python3
    ```

2. Install extra packages into `dom0`

    **WARNING!** Be very careful with installing non-critical cruft into `dom0`!
    **Read the [rules](https://docs.xcp-ng.org/management/additional-packages/#-rules) first!**

    ```bash
    make packages
    ```

3. Configure host and network settings

    3.1. **Host**: host name, time zone, locale and language  
    3.2. **Linux**: enable auto-continue in emergency mode  
    3.3. **XCP-ng**: enable GPU passthrough `dom0` to VMs  
    3.4. **Network**: DNS name servers and search domains

    ```bash
    make basics
    ```

4. Set up admin user's home directory

    4.1. symlinks `~/local-isos`, `~/shared-isos`, and `~/backups`  
    4.2. user dot files and README files

    ```bash
    make files
    ```

5. Create static DNS records in pfSense

    ```bash
    make dns
    ```

6. Create Kubernetes cluster VMs  
   Configure settings for _**ALL**_ VMs

    6.1. enable auto-starting VMs  
    6.2. enable GPU passthroughs _(relevant VMs must be **powered on**)_  
    6.3. configure VM CPU/memory _(relevant VMs must be **powered off**)_

    ```bash
    make vms
    ```

Alternatively, **run all playbooks** automatically in order:

```bash
# specify options like -v or -t
make -- [ansible-playbook-opts]

# run all playbooks starting from "basics"
# ("basics" is a playbook tag in main.yml)
make -- basics-

# run all playbooks up to "dns" (inclusive)
make -- -dns
```

Output from playbook runs will be logged in "`ansible.log`".

## Provisioning

Follow these steps when **adding a new XCP-ng node** to the cluster or **recreating an existing node** due to system failure:

1. Disable High Availability mode on the XCP-ng pool using Xen Orchestra (`Home` ➤ `Pools` ➤ `Homelab` ➤ `Advanced`)  
    so that the new host can join the pool later on.

2. Adjust the host's BIOS settings to auto-start after power recovery.

3. Boot the host with USB drive flashed with the XCP-ng 8.3 installer.

4. If the host contains multiple disks (e.g. `nvme0n1` and `nvme1n1`):

    a. Install XCP-ng onto the smaller disk _(do not choose "Software RAID" as that will create a RAID1 array using `mdadm`)_.  
    b. Select all disks for hosting virtual machines, and choose LVM _("thick provisioning")_ to create a single volume group.

5. Configure the host with these system and network settings:

    a. Use the host name and IP defined in `inventory/hosts.ini`  
    b. Use the DNS name servers defined in `vars/basics.yml`  
    c. Use the system time zone defined in `vars/basics.yml`  
    d. Use the XCP-ng root password defined in Ansible Vault

6. After installation is complete and the host has rebooted, select `Local Command Shell`  
    from the XCP-ng menu and run the following commands to apply the latest patches:

    ```bash
    yum clean all
    yum update -y
    reboot
    ```

7. After system update, select `Resource Pool Configuration` ➤ `Join a Resource Pool`,  
    then enter `192.168.0.151`, as well as the pool master root credentials, to join the pool.

8. If the new host is replacing an existing node, it's imperative that stale resources (SRs) from the old host be removed  
    from the pool. In Xen Orchestra, verify that each resource associated with the host is active, or else "forget" the SR.

9. Run all playbooks up to `dns` (`make -- -dns`). Along with various host customizations, `grub.cfg` will be modified  
    to enable GPU passthrough from `dom0` to VMs that will run on that host, thus requiring another reboot when done.

10. After rebooting the XCP-ng host, run the `vms` playbook (`make vms`) to provision VMs on that node using Terraform.

11. Lastly, re-enable High Availability mode on the XCP-ng pool using Xen Orchestra.

## Troubleshooting

1. If you encounter the following error, it means you're not using ansible-core version < 2.17.  
  Make sure you follow the [Requirements](#Requirements) and install Ansible in a Python virtual environment.

    ```
    SyntaxError: future feature annotations is not defined
    ```

2. Ansible's [ad-hoc commands](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html#managing-services) are useful in these scenarios.
  For example:

    ```bash
    ansible xcp_hosts -m ansible.builtin.raw -b -a "yum update"
    ansible xcp_hosts -m ansible.builtin.raw -b -a "ethtool eth0 |
        awk '/^\s+((Speed|Duplex|Link).+)$/ {NF++; print \$0}'"
    ```
