# Runbook: Bootstrap Proxmox

This runbook covers the one-time manual steps required on the Proxmox hosts before
OpenTofu can provision VMs. These steps cannot be automated with the bpg/proxmox
provider because they require access to the Proxmox web UI or SSH as root.

**Time required:** ~30 minutes per Proxmox host
**Risk level:** LOW — these are additive steps that do not affect existing VMs

---

## Prerequisites

- Both Proxmox hosts are installed and reachable on the network
- You have `root` access to both Proxmox hosts (via web UI or SSH)
- You have downloaded the Ubuntu 24.04 cloud image

---

## Step 1: Create the Proxmox API token

The `bpg/proxmox` OpenTofu provider authenticates using an API token, not a username
and password. Tokens are scoped to a specific user and can be revoked independently.

On each Proxmox host (or on the primary host if using a cluster):

### Via the Proxmox web UI

1. Log in to the Proxmox web UI (`https://<proxmox-ip>:8006`)
2. Navigate to **Datacenter → Permissions → API Tokens**
3. Click **Add**
4. Set:
   - **User:** `root@pam` (or create a dedicated user — recommended for least privilege)
   - **Token ID:** `opentofu` (or any descriptive name)
   - **Privilege Separation:** unchecked (token inherits user permissions)

5. Click **Add**
6. **Copy and save the token secret immediately.** It is shown only once.

The token format is: `<user>@<realm>!<token-id>=<secret>`
Example: `root@pam!opentofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Via SSH

```bash
pveum user token add root@pam opentofu --expire 0 --privsep=0
```

### Required permissions

If using a dedicated user instead of root, grant these permissions at the datacenter level:

```bash
pveum aclmod / -user opentofu@pam -role PVEVMAdmin
pveum aclmod /storage -user opentofu@pam -role PVEDatastoreAdmin
```

### Storing the token

Store the full token string in your password manager under "Proxmox OpenTofu API token".
It will be exported as an environment variable when running OpenTofu:

```bash
export PROXMOX_VE_API_TOKEN="root@pam!opentofu=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

**This value is never committed to git.**

---

## Step 2: Enable the snippets storage

The `bpg/proxmox` provider uploads cloud-init configuration files to Proxmox storage.
Proxmox storage must be configured to accept "Snippet" content types.

### Via the Proxmox web UI

1. Navigate to **Datacenter → Storage**
2. Select the `local` storage (or whichever storage you use for VM disks)
3. Click **Edit**
4. In the **Content** list, enable **Snippets** (in addition to any existing content types)
5. Click **OK**

### Via SSH

```bash
pvesm set local --content backup,images,snippets,vztmpl,iso,rootdir
```

Verify:
```bash
pvesm status
# Should show "local" with "active" status and snippets in the content list
```

---

## Step 3: Download the Ubuntu 24.04 cloud image

Create a cloud-init-ready VM template that OpenTofu will clone for new VMs.

SSH into each Proxmox host and run:

```bash
# Download the Ubuntu 24.04 cloud image (minimal, cloud-optimized)
wget -O /tmp/ubuntu-24.04-cloud.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Verify the checksum (get the SHA256SUMS file from the same URL)
wget -O /tmp/SHA256SUMS \
  https://cloud-images.ubuntu.com/noble/current/SHA256SUMS
grep "noble-server-cloudimg-amd64.img" /tmp/SHA256SUMS | \
  sed 's|noble-server-cloudimg-amd64.img|/tmp/ubuntu-24.04-cloud.img|' | \
  sha256sum -c
```

---

## Step 4: Create the VM template

Choose a template VM ID that will not conflict with your managed VMs. Convention: use
ID `9000` for templates.

> **Clustered Proxmox:** VM IDs are shared cluster-wide. Create the template on **one node only**.
> OpenTofu will handle cross-node cloning when provisioning VMs on other nodes — Proxmox
> copies the disk over the network automatically. Running `qm create 9000` on a second node
> will fail if the cluster already has a VM with that ID.

```bash
# Create a new VM (this becomes the template)
qm create 9000 \
  --name ubuntu-24.04-cloud-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

# Import the cloud image as a disk
qm importdisk 9000 /tmp/ubuntu-24.04-cloud.img local-lvm

# Attach the disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

# Add a cloud-init drive (required for cloud-init configuration)
qm set 9000 --ide2 local-lvm:cloudinit

# Set the boot disk and enable cloud-init
qm set 9000 --boot c --bootdisk scsi0

# Enable the QEMU guest agent (required for bpg provider to read VM IP)
qm set 9000 --agent enabled=1

# Set the display type
qm set 9000 --serial0 socket --vga serial0

# Convert to template
qm template 9000
```

Verify the template exists:
```bash
qm list | grep 9000
```

---

## Step 5: Note the storage and network configuration

OpenTofu needs to know the names of Proxmox storage and network resources. Capture these:

```bash
# List available storage pools
pvesm status

# List available network bridges
ip link show | grep vmbr
```

Record the values in `tofu/environments/homelab/terraform.tfvars.example` so they
are documented for reference when creating the real `terraform.tfvars` file.

Common values for a default Proxmox installation:
- Storage: `local-lvm` (for VM disks), `local` (for snippets)
- Network bridge: `vmbr0`

---

## Verification

Before running OpenTofu, verify the setup:

```bash
# Test API token access (replace with your values)
export PROXMOX_VE_API_TOKEN="root@pam!opentofu=<your-token-secret>"
export PROXMOX_VE_ENDPOINT="https://<proxmox-ip>:8006"

curl -s -k \
  -H "Authorization: PVEAPIToken=$PROXMOX_VE_API_TOKEN" \
  "$PROXMOX_VE_ENDPOINT/api2/json/nodes" | jq '.data[].node'
```

Expected output: the name(s) of your Proxmox node(s).

---

## Troubleshooting

**Error: "Permission check failed" when OpenTofu runs**
→ Verify the API token has the required permissions (Step 1).
→ Try with `root@pam` token to confirm it is a permissions issue.

**`tofu apply` hangs after VM is created**
→ The bpg provider is waiting for the VM's IP from qemu-guest-agent.
→ Verify the cloud-init image has `qemu-guest-agent` in its package list.
→ SSH into the VM (using the Proxmox console) and check: `systemctl status qemu-guest-agent`

**"No such storage" error during apply**
→ Verify the storage name in `terraform.tfvars` matches what `pvesm status` shows.

---

## Next step

With Proxmox configured, proceed to [Phase 1: VM Provisioning](../../tofu/README.md).
