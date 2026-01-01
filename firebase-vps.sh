#!/bin/bash
# ===================================================================
# 🚀 FIREBASE QEMU VPS - COMPLETE SINGLE FILE
# ===================================================================
# Complete QEMU VPS system with:
# 1. Original GitHub QEMU code
# 2. ALBIN banner and menu interface
# 3. 24/7 background operation
# 4. FULL customization: OS, RAM, CPU, Disk, Port, Credentials
# ===================================================================

set -euo pipefail

# Configuration
VM_BASE_DIR="$HOME/.firebase-qemu-vps"
VMS_DIR="$VM_BASE_DIR/vms"
CONFIG_DIR="$VM_BASE_DIR/config"
LOG_FILE="$VM_BASE_DIR/qemu-vps.log"

# Colors for UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# OS Configuration
declare -A OS_URLS=(
    ["ubuntu24"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["ubuntu22"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["ubuntu20"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
    ["debian12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ["debian11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    ["alpine"]="https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-virt-3.19.0-x86_64.iso"
)

declare -A OS_NAMES=(
    ["ubuntu24"]="Ubuntu 24.04 LTS (Noble)"
    ["ubuntu22"]="Ubuntu 22.04 LTS (Jammy)"
    ["ubuntu20"]="Ubuntu 20.04 LTS (Focal)"
    ["debian12"]="Debian 12 (Bookworm)"
    ["debian11"]="Debian 11 (Bullseye)"
    ["alpine"]="Alpine Linux 3.19"
)

# ==================== ORIGINAL GITHUB QEMU CODE ====================

run_original_qemu_vm() {
    local VM_NAME="$1"
    local VM_DIR="$2"
    local MEMORY="${3:-2G}"
    local CPUS="${4:-2}"
    local DISK_SIZE="${5:-20G}"
    local SSH_PORT="${6:-2222}"
    local USERNAME="${7:-ubuntu}"
    local PASSWORD="${8:-ubuntu}"
    local HOSTNAME="${9:-ubuntu}"
    local SWAP_SIZE="${10:-2G}"
    local OS_TYPE="${11:-ubuntu24}"
    
    cd "$VM_DIR"
    
    # Set image URL based on OS
    if [ -n "${OS_URLS[$OS_TYPE]}" ]; then
        IMG_URL="${OS_URLS[$OS_TYPE]}"
        OS_NAME="${OS_NAMES[$OS_TYPE]}"
    else
        IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
        OS_NAME="Ubuntu 24.04 LTS"
    fi
    
    IMG_FILE="$VM_DIR/cloud-image.img"
    PERSISTENT_DISK="$VM_DIR/persistent.qcow2"
    SEED_FILE="$VM_DIR/seed.iso"
    
    echo -e "${GREEN}Setting up QEMU VM: $VM_NAME ($OS_NAME)${NC}"
    
    # Check for required tools
    for cmd in qemu-system-x86_64 qemu-img cloud-localds; do
        if ! command -v $cmd &>/dev/null; then
            echo -e "${RED}[ERROR] Required command '$cmd' not found.${NC}"
            echo -e "${YELLOW}Installing dependencies...${NC}"
            sudo apt-get update
            sudo apt-get install -y qemu-system-x86 qemu-utils cloud-image-utils
            break
        fi
    done
    
    # Download VM image if not exists
    if [ ! -f "$IMG_FILE" ]; then
        echo -e "${YELLOW}[INFO] Downloading $OS_NAME image...${NC}"
        wget "$IMG_URL" -O "$IMG_FILE"
        qemu-img resize "$IMG_FILE" "$DISK_SIZE"
        
        # Create cloud-init config
        cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/$USERNAME
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: $PASSWORD
chpasswd:
  list: |
    $USERNAME:$PASSWORD
    root:$PASSWORD
  expire: false
packages:
  - openssh-server
  - curl
  - wget
  - vim
  - htop
runcmd:
  - systemctl restart ssh
  - echo "Welcome to $HOSTNAME - Firebase QEMU VPS" > /etc/motd
  - fallocate -l $SWAP_SIZE /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo '/swapfile none swap sw 0 0' >> /etc/fstab
EOF

        cat > meta-data <<EOF
instance-id: iid-$VM_NAME
local-hostname: $HOSTNAME
EOF

        cloud-localds "$SEED_FILE" user-data meta-data
        echo -e "${GREEN}[INFO] VM image setup complete!${NC}"
    else
        echo -e "${YELLOW}[INFO] VM image exists, skipping download...${NC}"
    fi
    
    # Create persistent disk if not exists
    if [ ! -f "$PERSISTENT_DISK" ]; then
        echo -e "${YELLOW}[INFO] Creating persistent disk...${NC}"
        qemu-img create -f qcow2 "$PERSISTENT_DISK" "$DISK_SIZE"
    fi
    
    # Check if KVM is available
    if [ -e /dev/kvm ]; then
        ACCELERATION_FLAG="-enable-kvm -cpu host"
        echo -e "${GREEN}[INFO] KVM available. Using hardware acceleration.${NC}"
    else
        ACCELERATION_FLAG="-accel tcg"
        echo -e "${YELLOW}[INFO] KVM not available. Using TCG emulation.${NC}"
    fi
    
    # Save VM configuration
    cat > "$VM_DIR/vm-config.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
OS_NAME="$OS_NAME"
VM_DIR="$VM_DIR"
MEMORY="$MEMORY"
CPUS="$CPUS"
DISK_SIZE="$DISK_SIZE"
SSH_PORT="$SSH_PORT"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
HOSTNAME="$HOSTNAME"
SWAP_SIZE="$SWAP_SIZE"
IMG_FILE="$IMG_FILE"
PERSISTENT_DISK="$PERSISTENT_DISK"
SEED_FILE="$SEED_FILE"
CREATED_AT="$(date)"
EOF
    
    echo -e "${GREEN}✅ QEMU VM configuration saved!${NC}"
    return 0
}

start_qemu_vm() {
    local VM_DIR="$1"
    local BACKGROUND="${2:-0}"
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    
    # Check if already running
    if [ -f "$VM_DIR/vm.pid" ] && kill -0 $(cat "$VM_DIR/vm.pid") 2>/dev/null; then
        echo -e "${YELLOW}VM $VM_NAME is already running!${NC}"
        return 0
    fi
    
    cd "$VM_DIR"
    
    # Determine acceleration
    if [ -e /dev/kvm ]; then
        ACCELERATION_FLAG="-enable-kvm -cpu host"
    else
        ACCELERATION_FLAG="-accel tcg"
    fi
    
    echo -e "${GREEN}Starting VM: $VM_NAME ($OS_NAME)${NC}"
    echo -e "${CYAN}SSH: ssh -p $SSH_PORT $USERNAME@localhost${NC}"
    echo -e "${CYAN}Password: $PASSWORD${NC}"
    
    if [ "$BACKGROUND" = "1" ]; then
        echo -e "${YELLOW}Starting in 24/7 background mode...${NC}"
        # Start in background with nohup for 24/7 operation
        nohup qemu-system-x86_64 \
            $ACCELERATION_FLAG \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
            -drive file="$PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
            -drive file="$SEED_FILE",format=raw,if=virtio \
            -boot order=c \
            -device virtio-net-pci,netdev=n0 \
            -netdev user,id=n0,hostfwd=tcp::$SSH_PORT-:22 \
            -nographic \
            -daemonize \
            -pidfile "$VM_DIR/vm.pid" > "$VM_DIR/qemu.log" 2>&1 &
        
        echo $! > "$VM_DIR/vm.pid"
        echo -e "${GREEN}✅ VM started in background (PID: $(cat "$VM_DIR/vm.pid"))${NC}"
        echo -e "${BLUE}Logs: $VM_DIR/qemu.log${NC}"
    else
        echo -e "${YELLOW}Starting in foreground (Ctrl+C to stop)...${NC}"
        echo "CREDIT: Original GitHub QEMU-freeroot"
        echo "OS: $OS_NAME"
        echo "Username: $USERNAME"
        echo "Password: $PASSWORD"
        read -n1 -r -p "Press any key to continue..."
        
        # Run in foreground
        exec qemu-system-x86_64 \
            $ACCELERATION_FLAG \
            -m "$MEMORY" \
            -smp "$CPUS" \
            -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
            -drive file="$PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
            -drive file="$SEED_FILE",format=raw,if=virtio \
            -boot order=c \
            -device virtio-net-pci,netdev=n0 \
            -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
            -nographic -serial mon:stdio
    fi
}

stop_qemu_vm() {
    local VM_DIR="$1"
    
    if [ -f "$VM_DIR/vm.pid" ]; then
        PID=$(cat "$VM_DIR/vm.pid")
        echo -e "${YELLOW}Stopping VM (PID: $PID)...${NC}"
        kill $PID 2>/dev/null || true
        sleep 2
        kill -9 $PID 2>/dev/null 2>/dev/null || true
        rm -f "$VM_DIR/vm.pid"
        echo -e "${GREEN}✅ VM stopped${NC}"
    else
        echo -e "${YELLOW}VM is not running${NC}"
    fi
}

# ==================== YOUR CUSTOM INTERFACE ====================

show_albin_banner() {
    clear
    echo -e "${PURPLE}"
    echo '╔══════════════════════════════════════════════════════════════╗'
    echo '║                                                              ║'
    echo '║    █████╗ ██╗     ██████╗ ██╗███╗   ██╗                     ║'
    echo '║   ██╔══██╗██║     ██╔══██╗██║████╗  ██║                     ║'
    echo '║   ███████║██║     ██████╔╝██║██╔██╗ ██║                     ║'
    echo '║   ██╔══██║██║     ██╔══██╗██║██║╚██╗██║                     ║'
    echo '║   ██║  ██║███████╗██████╔╝██║██║ ╚████║                     ║'
    echo '║   ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═══╝                     ║'
    echo '║                                                              ║'
    echo '║           F I R E B A S E   Q E M U   V P S                  ║'
    echo '║           Complete Customization with 24/7 Mode              ║'
    echo '║           Based on Original GitHub QEMU-freeroot             ║'
    echo '╚══════════════════════════════════════════════════════════════╝'
    echo -e "${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Choose OS, Resources, Credentials | Real QEMU Virtualization${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

initialize_system() {
    echo -e "${GREEN}Initializing Firebase QEMU VPS System...${NC}"
    mkdir -p "$VM_BASE_DIR"/{vms,config,backups,logs}
    echo -e "${GREEN}✅ System ready at $VM_BASE_DIR${NC}"
}

create_vps_wizard() {
    show_albin_banner
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                   CREATE NEW VPS - WIZARD                    ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get VPS name
    echo -n -e "${GREEN}Enter VPS name: ${NC}"
    read VM_NAME
    VM_NAME=${VM_NAME:-"vps-$(date +%s)"}
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' already exists!${NC}"
        echo -n -e "${YELLOW}Overwrite? (y/N): ${NC}"
        read OVERWRITE
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            return 1
        fi
        rm -rf "$VM_DIR"
    fi
    
    mkdir -p "$VM_DIR"
    
    # Step 1: Choose OS
    echo ""
    echo -e "${CYAN}Step 1: Select Operating System${NC}"
    echo "1) Ubuntu 24.04 LTS (Noble) - Latest"
    echo "2) Ubuntu 22.04 LTS (Jammy) - LTS"
    echo "3) Ubuntu 20.04 LTS (Focal) - LTS"
    echo "4) Debian 12 (Bookworm) - Stable"
    echo "5) Debian 11 (Bullseye) - Old Stable"
    echo "6) Alpine Linux 3.19 - Lightweight"
    echo ""
    echo -n -e "${GREEN}Choose OS [1-6]: ${NC}"
    read OS_CHOICE
    
    case $OS_CHOICE in
        1) OS_TYPE="ubuntu24" ;;
        2) OS_TYPE="ubuntu22" ;;
        3) OS_TYPE="ubuntu20" ;;
        4) OS_TYPE="debian12" ;;
        5) OS_TYPE="debian11" ;;
        6) OS_TYPE="alpine" ;;
        *) OS_TYPE="ubuntu24" ;;
    esac
    
    OS_NAME="${OS_NAMES[$OS_TYPE]}"
    echo -e "${BLUE}Selected: $OS_NAME${NC}"
    
    # Step 2: Resource Plan
    echo ""
    echo -e "${CYAN}Step 2: Select Resource Plan${NC}"
    echo "1) Basic (1GB RAM, 1 CPU, 10GB Disk)"
    echo "2) Standard (2GB RAM, 2 CPU, 20GB Disk) [Recommended]"
    echo "3) Advanced (4GB RAM, 4 CPU, 50GB Disk)"
    echo "4) Custom (Choose your own)"
    echo ""
    echo -n -e "${GREEN}Choose plan [1-4]: ${NC}"
    read PLAN_CHOICE
    
    case $PLAN_CHOICE in
        1)
            MEMORY="1G"
            CPUS="1"
            DISK_SIZE="10G"
            ;;
        2)
            MEMORY="2G"
            CPUS="2"
            DISK_SIZE="20G"
            ;;
        3)
            MEMORY="4G"
            CPUS="4"
            DISK_SIZE="50G"
            ;;
        4)
            echo -n -e "${GREEN}RAM (e.g., 2G): ${NC}"
            read MEMORY
            echo -n -e "${GREEN}CPU cores: ${NC}"
            read CPUS
            echo -n -e "${GREEN}Disk size (e.g., 25G): ${NC}"
            read DISK_SIZE
            MEMORY=${MEMORY:-2G}
            CPUS=${CPUS:-2}
            DISK_SIZE=${DISK_SIZE:-20G}
            ;;
        *)
            MEMORY="2G"
            CPUS="2"
            DISK_SIZE="20G"
            ;;
    esac
    
    # Step 3: Network Settings
    echo ""
    echo -e "${CYAN}Step 3: Network Settings${NC}"
    echo -n -e "${GREEN}SSH Port [2222]: ${NC}"
    read SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    
    # Step 4: Credentials
    echo ""
    echo -e "${CYAN}Step 4: Login Credentials${NC}"
    echo -n -e "${GREEN}Username [ubuntu]: ${NC}"
    read USERNAME
    USERNAME=${USERNAME:-ubuntu}
    
    echo -n -e "${GREEN}Password [ubuntu]: ${NC}"
    read -s PASSWORD
    echo
    PASSWORD=${PASSWORD:-ubuntu}
    
    # Step 5: System Settings
    echo ""
    echo -e "${CYAN}Step 5: System Settings${NC}"
    echo -n -e "${GREEN}Hostname [$VM_NAME]: ${NC}"
    read HOSTNAME
    HOSTNAME=${HOSTNAME:-$VM_NAME}
    
    echo -n -e "${GREEN}Swap Size [2G]: ${NC}"
    read SWAP_SIZE
    SWAP_SIZE=${SWAP_SIZE:-2G}
    
    # Summary
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                   CONFIGURATION SUMMARY                    ${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}VPS Name:${NC}   $VM_NAME"
    echo -e "${GREEN}OS:${NC}         $OS_NAME"
    echo -e "${GREEN}Resources:${NC}  $MEMORY RAM, $CPUS CPU, $DISK_SIZE Disk"
    echo -e "${GREEN}SSH Port:${NC}   $SSH_PORT"
    echo -e "${GREEN}Username:${NC}   $USERNAME"
    echo -e "${GREEN}Password:${NC}   $PASSWORD"
    echo -e "${GREEN}Hostname:${NC}   $HOSTNAME"
    echo -e "${GREEN}Swap:${NC}       $SWAP_SIZE"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -n -e "${YELLOW}Create this VPS? (Y/n): ${NC}"
    read CONFIRM
    if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        return 1
    fi
    
    # Create the VPS
    echo -e "${YELLOW}Setting up QEMU VM...${NC}"
    run_original_qemu_vm "$VM_NAME" "$VM_DIR" "$MEMORY" "$CPUS" "$DISK_SIZE" "$SSH_PORT" "$USERNAME" "$PASSWORD" "$HOSTNAME" "$SWAP_SIZE" "$OS_TYPE"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║      QEMU VPS CREATED SUCCESSFULLY!     ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}Access Information:${NC}"
    echo "Location: $VM_DIR"
    echo "SSH: ssh -p $SSH_PORT $USERNAME@localhost"
    echo "Password: $PASSWORD"
    echo ""
    
    # Ask to start
    echo -n -e "${YELLOW}Start VPS now? (Y/n): ${NC}"
    read START_NOW
    if [[ ! "$START_NOW" == "n" && ! "$START_NOW" == "N" ]]; then
        echo -n -e "${YELLOW}Start in 24/7 background mode? (Y/n): ${NC}"
        read BACKGROUND_MODE
        if [[ ! "$BACKGROUND_MODE" == "n" && ! "$BACKGROUND_MODE" == "N" ]]; then
            start_qemu_vm "$VM_DIR" "1"
            echo ""
            echo -e "${GREEN}✅ VPS running in 24/7 background mode${NC}"
            echo -e "${BLUE}Check status: ./$(basename "$0") list${NC}"
        else
            start_qemu_vm "$VM_DIR" "0"
        fi
    fi
}

list_vps() {
    show_albin_banner
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                   YOUR QEMU VPS INSTANCES                   ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    if [ ! -d "$VMS_DIR" ] || [ -z "$(ls -A "$VMS_DIR" 2>/dev/null)" ]; then
        echo -e "${RED}No VPS instances found.${NC}"
        echo ""
        return
    fi
    
    local COUNT=1
    for VM in "$VMS_DIR"/*; do
        if [ -d "$VM" ]; then
            VM_NAME=$(basename "$VM")
            CONFIG_FILE="$VM/vm-config.conf"
            
            if [ -f "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE" 2>/dev/null
                
                echo -e "${GREEN}$COUNT. $VM_NAME${NC}"
                echo -e "${BLUE}   OS:${NC} $OS_NAME"
                echo -e "${BLUE}   Resources:${NC} $MEMORY RAM, $CPUS CPU, $DISK_SIZE Disk"
                echo -e "${BLUE}   SSH:${NC} port $SSH_PORT | User: $USERNAME"
                echo -e "${BLUE}   Created:${NC} $CREATED_AT"
                
                if [ -f "$VM/vm.pid" ] && kill -0 $(cat "$VM/vm.pid") 2>/dev/null; then
                    echo -e "   ${GREEN}● Status: RUNNING (24/7)${NC}"
                else
                    echo -e "   ${RED}● Status: STOPPED${NC}"
                fi
                
                echo "   Location: $VM"
                echo ""
                ((COUNT++))
            fi
        fi
    done
    
    echo -e "${CYAN}Total VPS: $((COUNT-1))${NC}"
    echo ""
}

start_vps() {
    local VM_NAME="$1"
    local BACKGROUND="${2:-1}"
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ ! -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    
    if [ "$BACKGROUND" = "1" ]; then
        echo -e "${GREEN}Starting '$VM_NAME' ($OS_NAME) in 24/7 background mode...${NC}"
        start_qemu_vm "$VM_DIR" "1"
    else
        echo -e "${GREEN}Starting '$VM_NAME' ($OS_NAME) in foreground...${NC}"
        start_qemu_vm "$VM_DIR" "0"
    fi
}

stop_vps() {
    local VM_NAME="$1"
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ ! -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    echo -e "${GREEN}Stopping '$VM_NAME' ($OS_NAME)...${NC}"
    stop_qemu_vm "$VM_DIR"
}

connect_vps() {
    local VM_NAME="$1"
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ ! -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    
    echo -e "${GREEN}Connecting to VPS: $VM_NAME ($OS_NAME)${NC}"
    echo -e "${CYAN}SSH Command:${NC}"
    echo "  ssh -p $SSH_PORT $USERNAME@localhost"
    echo -e "${CYAN}Password:${NC} $PASSWORD"
    echo ""
    echo -e "${YELLOW}Press Ctrl+D or type 'exit' to disconnect${NC}"
    echo ""
    
    ssh -o "StrictHostKeyChecking=no" -p $SSH_PORT $USERNAME@localhost
}

quick_connect() {
    # Quick connect without showing all details
    local VM_NAME="$1"
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ ! -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    
    # Check if VM is running
    if [ ! -f "$VM_DIR/vm.pid" ] || ! kill -0 $(cat "$VM_DIR/vm.pid") 2>/dev/null; then
        echo -e "${YELLOW}VPS is not running. Starting in background...${NC}"
        start_qemu_vm "$VM_DIR" "1"
        sleep 3
    fi
    
    ssh -o "StrictHostKeyChecking=no" -p $SSH_PORT $USERNAME@localhost
}

delete_vps() {
    local VM_NAME="$1"
    
    VM_DIR="$VMS_DIR/$VM_NAME"
    
    if [ ! -d "$VM_DIR" ]; then
        echo -e "${RED}VPS '$VM_NAME' not found!${NC}"
        return 1
    fi
    
    if [ ! -f "$VM_DIR/vm-config.conf" ]; then
        echo -e "${RED}VM configuration not found!${NC}"
        return 1
    fi
    
    source "$VM_DIR/vm-config.conf"
    
    echo -e "${RED}⚠️  WARNING: This will permanently delete VPS '$VM_NAME' ($OS_NAME)${NC}"
    echo -e "${RED}All data will be lost!${NC}"
    echo ""
    echo -n -e "${YELLOW}Type 'DELETE' to confirm: ${NC}"
    read CONFIRM
    
    if [ "$CONFIRM" = "DELETE" ]; then
        stop_qemu_vm "$VM_DIR" 2>/dev/null
        rm -rf "$VM_DIR"
        echo -e "${GREEN}✅ VPS '$VM_NAME' deleted${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled${NC}"
    fi
}

show_system_info() {
    show_albin_banner
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                     SYSTEM INFORMATION                      ${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Count VPS
    local VPS_COUNT=0
    local RUNNING_COUNT=0
    if [ -d "$VMS_DIR" ]; then
        VPS_COUNT=$(ls -d "$VMS_DIR"/* 2>/dev/null | wc -l)
        
        for VM in "$VMS_DIR"/*; do
            if [ -d "$VM" ] && [ -f "$VM/vm.pid" ] && kill -0 $(cat "$VM/vm.pid") 2>/dev/null; then
                ((RUNNING_COUNT++))
            fi
        done
    fi
    
    echo -e "${CYAN}VPS System:${NC}"
    echo "  Base Directory: $VM_BASE_DIR"
    echo "  Total VPS: $VPS_COUNT"
    echo "  Running: $RUNNING_COUNT"
    echo "  Stopped: $((VPS_COUNT - RUNNING_COUNT))"
    echo ""
    
    echo -e "${CYAN}Hardware/Software:${NC}"
    echo "  QEMU Available: $(command -v qemu-system-x86_64 >/dev/null && echo '✅ Yes' || echo '❌ No')"
    echo "  KVM Available: $([ -e /dev/kvm ] && echo '✅ Yes' || echo '❌ No')"
    echo "  Cloud-Utils: $(command -v cloud-localds >/dev/null && echo '✅ Yes' || echo '❌ No')"
    echo ""
    
    echo -e "${CYAN}Available OS Images:${NC}"
    for os in "${!OS_NAMES[@]}"; do
        echo "  ${OS_NAMES[$os]}"
    done
    echo ""
}

show_help() {
    echo -e "${CYAN}Firebase QEMU VPS Manager${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create                    Launch VPS creation wizard"
    echo "  list                      List all VPS instances"
    echo "  start <name> [bg]         Start VPS (bg=1 for 24/7 mode)"
    echo "  stop <name>               Stop a running VPS"
    echo "  connect <name>            SSH into a VPS"
    echo "  quick <name>              Quick SSH (auto-start if needed)"
    echo "  delete <name>             Delete a VPS"
    echo "  info                      Show system information"
    echo "  menu                      Interactive menu (default)"
    echo ""
    echo "Examples:"
    echo "  $0 create                 Create new VPS with full wizard"
    echo "  $0 start myvps 1          Start 'myvps' in 24/7 background"
    echo "  $0 connect myvps          SSH into 'myvps'"
    echo "  $0 quick myvps            Quick connect with auto-start"
    echo "  $0 list                   List all VPS"
}

interactive_menu() {
    while true; do
        show_albin_banner
        
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${WHITE}                      MAIN MENU                             ${NC}"
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}1.${NC} Create New VPS (Full Wizard)"
        echo -e "${GREEN}2.${NC} List All VPS"
        echo -e "${GREEN}3.${NC} Start VPS (24/7 Background)"
        echo -e "${GREEN}4.${NC} Start VPS (Foreground)"
        echo -e "${GREEN}5.${NC} Stop VPS"
        echo -e "${GREEN}6.${NC} Connect to VPS (SSH)"
        echo -e "${GREEN}7.${NC} Quick Connect (Auto-start)"
        echo -e "${GREEN}8.${NC} Delete VPS"
        echo -e "${GREEN}9.${NC} System Information"
        echo -e "${GREEN}0.${NC} Exit"
        echo ""
        
        # Count VPS
        local VPS_COUNT=0
        if [ -d "$VMS_DIR" ]; then
            VPS_COUNT=$(ls -d "$VMS_DIR"/* 2>/dev/null | wc -l)
        fi
        
        echo -e "${CYAN}📊 Statistics: $VPS_COUNT VPS total${NC}"
        echo ""
        
        echo -n -e "${YELLOW}Select option [0-9]: ${NC}"
        read CHOICE
        
        case $CHOICE in
            1)
                create_vps_wizard
                ;;
            2)
                list_vps
                ;;
            3)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    start_vps "$VM_NAME" "1"
                fi
                ;;
            4)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    start_vps "$VM_NAME" "0"
                fi
                ;;
            5)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    stop_vps "$VM_NAME"
                fi
                ;;
            6)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    connect_vps "$VM_NAME"
                fi
                ;;
            7)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    quick_connect "$VM_NAME"
                fi
                ;;
            8)
                echo ""
                echo -n -e "${GREEN}Enter VPS name: ${NC}"
                read VM_NAME
                if [ -n "$VM_NAME" ]; then
                    delete_vps "$VM_NAME"
                fi
                ;;
            9)
                show_system_info
                ;;
            0)
                echo ""
                echo -e "${GREEN}Thank you for using Firebase QEMU VPS!${NC}"
                echo -e "${YELLOW}Your VPS continue running in background.${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        echo -n -e "${CYAN}Press Enter to continue...${NC}"
        read _
    done
}

# ==================== MAIN ENTRY POINT ====================

# Initialize system
initialize_system

# Parse command line arguments
if [ $# -eq 0 ]; then
    interactive_menu
else
    case "$1" in
        "create")
            create_vps_wizard
            ;;
        "list")
            list_vps
            ;;
        "start")
            if [ -n "$2" ]; then
                start_vps "$2" "${3:-1}"
            else
                echo -e "${RED}Error: VPS name required${NC}"
                show_help
            fi
            ;;
        "stop")
            if [ -n "$2" ]; then
                stop_vps "$2"
            else
                echo -e "${RED}Error: VPS name required${NC}"
                show_help
            fi
            ;;
        "connect")
            if [ -n "$2" ]; then
                connect_vps "$2"
            else
                echo -e "${RED}Error: VPS name required${NC}"
                show_help
            fi
            ;;
        "quick")
            if [ -n "$2" ]; then
                quick_connect "$2"
            else
                echo -e "${RED}Error: VPS name required${NC}"
                show_help
            fi
            ;;
        "delete")
            if [ -n "$2" ]; then
                delete_vps "$2"
            else
                echo -e "${RED}Error: VPS name required${NC}"
                show_help
            fi
            ;;
        "info")
            show_system_info
            ;;
        "menu")
            interactive_menu
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            show_help
            ;;
    esac
fi
