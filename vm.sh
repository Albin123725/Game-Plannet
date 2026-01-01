#!/bin/bash
set -euo pipefail

# =============================
# UBUNTU VM FILE - FIREBASE EDITION
# CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming
# =============================

# =============================
# CONFIG
# =============================
VM_DIR="$(pwd)/vm"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_FILE="$VM_DIR/ubuntu-image.img"
UBUNTU_PERSISTENT_DISK="$VM_DIR/persistent.qcow2"
SEED_FILE="$VM_DIR/seed.iso"
MEMORY=16G
CPUS=4
SSH_PORT=2222
DISK_SIZE=80G
IMG_SIZE=20G
HOSTNAME="ubuntu"
USERNAME="ubuntu"
PASSWORD="ubuntu"
SWAP_SIZE=4G

# Firebase Environment Detection (safe check)
IS_FIREBASE=0
if [ -n "${GOOGLE_CLOUD_PROJECT:-}" ] || 
   [ -n "${FIREBASE_ENVIRONMENT:-}" ] || 
   hostname 2>/dev/null | grep -q "codespaces\|gitpod\|firebase" ||
   [ -f "/.firebaseconfig" ] || 
   [ -d "/home/firebase" ] ||
   whoami | grep -q "firebase"; then
    IS_FIREBASE=1
    echo "[INFO] Firebase/Cloud environment detected"
fi

# ALBIN Banner Display
show_banner() {
    clear
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║   █████╗ ██╗     ██████╗ ██╗███╗   ██╗                  ║"
    echo "║  ██╔══██╗██║     ██╔══██╗██║████╗  ██║                  ║"
    echo "║  ███████║██║     ██████╔╝██║██╔██╗ ██║                  ║"
    echo "║  ██╔══██║██║     ██╔══██╗██║██║╚██╗██║                  ║"
    echo "║  ██║  ██║███████╗██████╔╝██║██║ ╚████║                  ║"
    echo "║  ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═══╝                  ║"
    echo "║                                                          ║"
    echo "║           QEMU-freeroot VPS Manager v2.0                 ║"
    echo "║               Firebase Edition - 24/7 Mode               ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# Firebase-compatible service management
firebase_service() {
    PID_FILE="$HOME/.qemu-freeroot.pid"
    LOG_FILE="$HOME/.qemu-freeroot.log"
    
    case "$1" in
        start)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "[INFO] VM is already running (PID: $pid)"
                    return 0
                fi
            fi
            
            echo "[INFO] Starting VM in 24/7 Firebase background mode..."
            nohup bash "$0" --background > "$LOG_FILE" 2>&1 &
            echo $! > "$PID_FILE"
            echo "[SUCCESS] VM started in 24/7 mode (PID: $!)"
            echo "[INFO] SSH: ssh $USERNAME@localhost -p $SSH_PORT"
            echo "[INFO] Logs: tail -f $LOG_FILE"
            ;;
        stop)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                kill "$pid" 2>/dev/null || true
                rm -f "$PID_FILE"
                echo "[INFO] Stopped background VM (PID: $pid)"
            fi
            pkill -f "qemu-system-x86_64" 2>/dev/null || true
            echo "[SUCCESS] All VM instances stopped"
            ;;
        status)
            if [ -f "$PID_FILE" ]; then
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "[INFO] ✅ VM is running in 24/7 mode (PID: $pid)"
                    echo "[INFO]   SSH Port: $SSH_PORT"
                    echo "[INFO]   Username: $USERNAME"
                    echo "[INFO]   Password: $PASSWORD"
                    echo "[INFO]   Log file: $LOG_FILE"
                    return 0
                else
                    echo "[INFO] ❌ VM is not running (stale PID file)"
                    rm -f "$PID_FILE"
                fi
            else
                if pgrep -f "qemu-system-x86_64" > /dev/null; then
                    echo "[INFO] ⚠️  VM is running but not managed by 24/7 service"
                else
                    echo "[INFO] ❌ VM is not running"
                fi
            fi
            ;;
        logs)
            if [ -f "$LOG_FILE" ]; then
                tail -f "$LOG_FILE"
            else
                echo "[INFO] No log file found"
            fi
            ;;
        *)
            echo "Usage: $0 --service [start|stop|status|logs]"
            ;;
    esac
}

# Interactive Menu
show_menu() {
    while true; do
        show_banner
        
        echo "════════════════════ Current Configuration ════════════════════"
        echo "┌─────────────────────────────────────────────────────────────┐"
        echo "│  Hostname: $HOSTNAME"
        echo "│  Username: $USERNAME"
        echo "│  Password: $PASSWORD"
        echo "│  Memory: $MEMORY"
        echo "│  CPU Cores: $CPUS"
        echo "│  Disk Size: $DISK_SIZE"
        echo "│  SSH Port: $SSH_PORT"
        echo "│  Swap Size: $SWAP_SIZE"
        echo "│  Environment: $(if [ $IS_FIREBASE -eq 1 ]; then echo 'Firebase'; else echo 'Local'; fi)"
        echo "└─────────────────────────────────────────────────────────────┘"
        echo ""
        echo "═══════════════════════ Main Menu ════════════════════════"
        echo "1) 🚀 Start VM (Interactive Mode)"
        echo "2) 🌙 Start VM (24/7 Background Mode)"
        echo "3) ⚙️  Configure Custom Settings"
        echo "4) 📊 Check 24/7 Service Status"
        echo "5) ⏹️  Stop 24/7 Service"
        echo "6) 📋 View 24/7 Service Logs"
        echo "7) 🛠️  Quick Settings Presets"
        echo "8) 🚪 Exit to Terminal"
        echo "9) 🔄 Restart 24/7 Service"
        echo ""
        
        read -p "Select option (1-9): " choice
        
        case $choice in
            1)
                echo "[INFO] Starting in interactive mode..."
                INTERACTIVE_MODE=1
                break
                ;;
            2)
                echo "[INFO] Starting 24/7 background service..."
                firebase_service start
                read -p "Press any key to continue..."
                ;;
            3)
                customize_settings
                ;;
            4)
                firebase_service status
                read -p "Press any key to continue..."
                ;;
            5)
                firebase_service stop
                read -p "Press any key to continue..."
                ;;
            6)
                firebase_service logs
                ;;
            7)
                quick_presets
                ;;
            8)
                echo "[INFO] Exiting to terminal..."
                exit 0
                ;;
            9)
                echo "[INFO] Restarting 24/7 service..."
                firebase_service stop
                sleep 2
                firebase_service start
                read -p "Press any key to continue..."
                ;;
            *)
                echo "[ERROR] Invalid option!"
                sleep 1
                ;;
        esac
    done
}

# Quick Presets
quick_presets() {
    show_banner
    echo "════════════════════ Quick Presets ════════════════════"
    echo "1) 🎮 Gaming VM (8GB RAM, 4 CPU, 100GB Disk)"
    echo "2) 🖥️  Dev VM (4GB RAM, 2 CPU, 50GB Disk)"
    echo "3) 🐳 Docker VM (16GB RAM, 8 CPU, 200GB Disk)"
    echo "4) 🚀 High Performance (32GB RAM, 16 CPU, 500GB Disk)"
    echo "5) 🔙 Back to Main Menu"
    echo ""
    
    read -p "Select preset (1-5): " preset
    
    case $preset in
        1)
            MEMORY="8G"
            CPUS="4"
            DISK_SIZE="100G"
            echo "[SUCCESS] Gaming preset applied!"
            ;;
        2)
            MEMORY="4G"
            CPUS="2"
            DISK_SIZE="50G"
            echo "[SUCCESS] Dev preset applied!"
            ;;
        3)
            MEMORY="16G"
            CPUS="8"
            DISK_SIZE="200G"
            echo "[SUCCESS] Docker preset applied!"
            ;;
        4)
            MEMORY="32G"
            CPUS="16"
            DISK_SIZE="500G"
            echo "[SUCCESS] High Performance preset applied!"
            ;;
        5)
            return
            ;;
        *)
            echo "[ERROR] Invalid preset!"
            ;;
    esac
    
    save_config
    sleep 1
}

# Customize Settings
customize_settings() {
    show_banner
    echo "════════════════════ Customize Settings ════════════════════"
    
    echo "1) Change Hostname [Current: $HOSTNAME]"
    echo "2) Change Username [Current: $USERNAME]"
    echo "3) Change Password [Current: $PASSWORD]"
    echo "4) Change Memory [Current: $MEMORY]"
    echo "5) Change CPU Cores [Current: $CPUS]"
    echo "6) Change Disk Size [Current: $DISK_SIZE]"
    echo "7) Change SSH Port [Current: $SSH_PORT]"
    echo "8) Change Swap Size [Current: $SWAP_SIZE]"
    echo "9) Save & Return to Main Menu"
    echo ""
    
    read -p "Select option (1-9): " choice
    
    case $choice in
        1) read -p "New Hostname: " HOSTNAME ;;
        2) read -p "New Username: " USERNAME ;;
        3) read -p "New Password: " PASSWORD ;;
        4) read -p "New Memory (e.g., 8G, 16G): " MEMORY ;;
        5) read -p "New CPU Cores: " CPUS ;;
        6) read -p "New Disk Size (e.g., 40G, 80G): " DISK_SIZE ;;
        7) read -p "New SSH Port: " SSH_PORT ;;
        8) read -p "New Swap Size (0G to disable): " SWAP_SIZE ;;
        9)
            echo "[INFO] Settings saved!"
            save_config
            return
            ;;
        *)
            echo "[ERROR] Invalid option!"
            sleep 1
            return
            ;;
    esac
    
    save_config
    echo "[SUCCESS] Configuration saved!"
    sleep 1
}

# Save configuration
save_config() {
    mkdir -p "$VM_DIR"
    cat > "$VM_DIR/vm.config" <<EOF
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
MEMORY="$MEMORY"
CPUS="$CPUS"
DISK_SIZE="$DISK_SIZE"
SSH_PORT="$SSH_PORT"
SWAP_SIZE="$SWAP_SIZE"
EOF
}

# Load saved config
load_config() {
    if [ -f "$VM_DIR/vm.config" ]; then
        # Use safe source to avoid issues
        if [ -r "$VM_DIR/vm.config" ]; then
            while IFS='=' read -r key value; do
                # Skip comments and empty lines
                [[ $key =~ ^[[:space:]]*# ]] && continue
                [[ -z $key ]] && continue
                
                # Remove quotes from value
                value="${value%\"}"
                value="${value#\"}"
                
                # Export variable
                export "$key"="$value"
            done < "$VM_DIR/vm.config"
            echo "[INFO] Loaded saved configuration from $VM_DIR/vm.config"
        fi
    fi
}

# Parse command line arguments
parse_args() {
    case "${1:-}" in
        --menu|-m)
            show_menu
            ;;
        --background|-b)
            BACKGROUND_MODE=1
            ;;
        --service|-s)
            if [ -n "${2:-}" ]; then
                firebase_service "$2"
                exit 0
            else
                echo "Usage: $0 --service [start|stop|status|logs]"
                exit 1
            fi
            ;;
        --stop)
            firebase_service stop
            exit 0
            ;;
        --status)
            firebase_service status
            exit 0
            ;;
        --logs)
            firebase_service logs
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            # No arguments, continue normally
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                 QEMU-freeroot VM Manager                ║"
    echo "║                  Firebase 24/7 Edition                  ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --menu, -m        Show interactive menu with ALBIN banner"
    echo "  --background, -b  Start VM in 24/7 background mode"
    echo "  --service, -s     Manage 24/7 Firebase service"
    echo "                    [start|stop|status|logs]"
    echo "  --stop            Stop all running VM instances"
    echo "  --status          Check 24/7 service status"
    echo "  --logs            View 24/7 service logs"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Start VM normally"
    echo "  $0 --menu          # Show interactive menu"
    echo "  $0 --background    # Run in 24/7 background mode"
    echo "  $0 --service start # Start 24/7 Firebase service"
    echo "  $0 --status        # Check if VM is running"
    echo ""
    echo "Firebase Notes:"
    echo "  - 24/7 mode uses nohup background processes"
    echo "  - VM persists until explicitly stopped"
    echo "  - SSH: ssh $USERNAME@localhost -p $SSH_PORT"
}

# =============================
# MAIN EXECUTION
# =============================

# Load saved configuration
load_config

# Parse command line arguments
if [ $# -gt 0 ]; then
    parse_args "$@"
elif [ -t 0 ] && [ -t 1 ]; then
    # If running in terminal with no args, show menu
    show_menu
fi

# Create VM directory if it doesn't exist
mkdir -p "$VM_DIR"
cd "$VM_DIR"

# =============================
# TOOL CHECK
# =============================
for cmd in qemu-system-x86_64 qemu-img cloud-localds; do
    if ! command -v $cmd &>/dev/null; then
        echo "[ERROR] Required command '$cmd' not found. Install it first."
        exit 1
    fi
done

# =============================
# VM IMAGE SETUP
# =============================
if [ ! -f "$IMG_FILE" ]; then
    echo "[INFO] Downloading Ubuntu Base/Cloud Image..."
    wget "$IMG_URL" -O "$IMG_FILE"
    qemu-img resize "$IMG_FILE" "$DISK_SIZE"

    # Cloud-init setup for OpenSSH and Swap
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
manage_etc_hosts: true
disable_root: false
ssh_pwauth: true
chpasswd:
  list: |
    $USERNAME:$PASSWORD
  expire: false
packages:
  - openssh-server
runcmd:
  - echo "$USERNAME:$PASSWORD" | chpasswd
  - mkdir -p /var/run/sshd
  - /usr/sbin/sshd -D &
  # Swap file creation and activation
  - fallocate -l $SWAP_SIZE /swapfile
  - chmod 600 /swapfile
  - mkswap /swapfile
  - swapon /swapfile
  - echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    
growpart:
  mode: auto
  devices: ["/"]
  ignore_growroot_disabled: false
resize_rootfs: true
EOF

    cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: $HOSTNAME
EOF

    cloud-localds "$SEED_FILE" user-data meta-data
    echo "[INFO] VM image setup complete with OpenSSH and Swap!"
else
    echo "[INFO] VM image exists, skipping download..."
fi

# =============================
# PERSISTENT DISK SETUP
# =============================
if [ ! -f "$UBUNTU_PERSISTENT_DISK" ]; then
    echo "[INFO] Creating persistent disk..."
    qemu-img create -f qcow2 "$UBUNTU_PERSISTENT_DISK" "$IMG_SIZE"
fi

# =============================
# GRACEFUL SHUTDOWN TRAP
# =============================
cleanup() {
    echo "[INFO] Shutting down VM gracefully..."
    pkill -f "qemu-system-x86_64" || true
}
trap cleanup SIGINT SIGTERM

# =============================
# START VM
# =============================
# Check if KVM is available
clear
if [ -e /dev/kvm ]; then
    ACCELERATION_FLAG="-enable-kvm -cpu host"
    echo "[INFO] KVM is available. Using hardware acceleration."
else
    ACCELERATION_FLAG="-accel tcg"
    echo "[INFO] KVM is not available. Falling back to TCG software emulation."
fi

# Show banner for interactive mode
if [ -z "${BACKGROUND_MODE:-}" ] && [ -z "${INTERACTIVE_MODE:-}" ]; then
    show_banner
    echo "CREDIT: quanvm0501 (BlackCatOfficial), BiraloGaming"
    echo "[INFO] Starting VM..."
    echo "════════════════════ VM Details ════════════════════"
    echo "Hostname: $HOSTNAME"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "Memory: $MEMORY"
    echo "CPU Cores: $CPUS"
    echo "Disk Size: $DISK_SIZE"
    echo "SSH Port: $SSH_PORT"
    echo "Swap Size: $SWAP_SIZE"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "[TIP] Use './vm.sh --menu' for interactive menu"
    echo "[TIP] Use './vm.sh --service start' for 24/7 mode"
    echo ""
    read -n1 -r -p "Press any key to start VM..."
fi

# Build QEMU command
QEMU_CMD="qemu-system-x86_64 \
    $ACCELERATION_FLAG \
    -m \"$MEMORY\" \
    -smp \"$CPUS\" \
    -drive file=\"$IMG_FILE\",format=qcow2,if=virtio,cache=writeback \
    -drive file=\"$UBUNTU_PERSISTENT_DISK\",format=qcow2,if=virtio,cache=writeback \
    -drive file=\"$SEED_FILE\",format=raw,if=virtio \
    -boot order=c \
    -device virtio-net-pci,netdev=n0 \
    -netdev user,id=n0,hostfwd=tcp::\"$SSH_PORT\"-:22 \
    -nographic -serial mon:stdio"

# Add daemonize flag for background mode
if [ -n "${BACKGROUND_MODE:-}" ]; then
    QEMU_CMD="$QEMU_CMD -daemonize"
    echo "[INFO] Starting VM in 24/7 Firebase background mode..."
    echo "[INFO] VM will continue running even when you close browser"
    echo "[INFO] SSH: ssh $USERNAME@localhost -p $SSH_PORT"
    echo "[INFO] Use './vm.sh --status' to check if it's running"
    echo "[INFO] Use './vm.sh --stop' to stop it"
    eval $QEMU_CMD
    echo "[SUCCESS] VM is now running in 24/7 background mode!"
    exit 0
else
    echo "[INFO] Starting VM..."
    exec qemu-system-x86_64 \
        $ACCELERATION_FLAG \
        -m "$MEMORY" \
        -smp "$CPUS" \
        -drive file="$IMG_FILE",format=qcow2,if=virtio,cache=writeback \
        -drive file="$UBUNTU_PERSISTENT_DISK",format=qcow2,if=virtio,cache=writeback \
        -drive file="$SEED_FILE",format=raw,if=virtio \
        -boot order=c \
        -device virtio-net-pci,netdev=n0 \
        -netdev user,id=n0,hostfwd=tcp::"$SSH_PORT"-:22 \
        -nographic -serial mon:stdio
fi
