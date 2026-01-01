
---

**[file name]: vm.sh**
```bash
#!/bin/bash
set -euo pipefail

# =============================
# UBUNTU VM FILE
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
# use this if you are using tcg
# if not, simply set it to 0G
SWAP_SIZE=4G
SERVICE_NAME="qemu-freeroot-vps"
USER_SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$USER_SERVICE_DIR/$SERVICE_NAME.service"

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
    echo "║           24/7 Background Operation Enabled              ║"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
}

# Service Management
manage_service() {
    mkdir -p "$USER_SERVICE_DIR"
    
    case "$1" in
        create)
            cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=QEMU-freeroot 24/7 VPS Service
After=network.target
Wants=network.target

[Service]
Type=forking
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/vm.sh --background
ExecStop=$(pwd)/vm.sh --stop
Restart=always
RestartSec=10
User=$(whoami)
Group=$(whoami)

[Install]
WantedBy=default.target
EOF
            systemctl --user daemon-reload
            systemctl --user enable "$SERVICE_NAME"
            echo "[SUCCESS] 24/7 service created and enabled!"
            ;;
        start)
            systemctl --user start "$SERVICE_NAME"
            echo "[SUCCESS] 24/7 service started!"
            ;;
        stop)
            systemctl --user stop "$SERVICE_NAME"
            echo "[SUCCESS] 24/7 service stopped!"
            ;;
        status)
            systemctl --user status "$SERVICE_NAME" --no-pager || true
            ;;
        enable)
            systemctl --user enable "$SERVICE_NAME"
            echo "[SUCCESS] 24/7 service enabled for auto-start!"
            ;;
        disable)
            systemctl --user disable "$SERVICE_NAME"
            echo "[SUCCESS] 24/7 service disabled!"
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
        echo "└─────────────────────────────────────────────────────────────┘"
        echo ""
        echo "═══════════════════════ Main Menu ════════════════════════"
        echo "1) Start VM (Interactive Mode)"
        echo "2) Start VM (Background 24/7 Mode)"
        echo "3) Configure Custom Settings"
        echo "4) 24/7 Service Management"
        echo "5) Check Service Status"
        echo "6) Stop All VM Instances"
        echo "7) Exit to Terminal"
        echo "8) Start with Default Settings"
        echo ""
        
        read -p "Select option (1-8): " choice
        
        case $choice in
            1)
                echo "[INFO] Starting in interactive mode..."
                # Continue to normal execution
                break
                ;;
            2)
                echo "[INFO] Starting in 24/7 background mode..."
                nohup bash "$0" --background > /dev/null 2>&1 &
                echo "[SUCCESS] VM started in background (PID: $!)"
                echo "SSH: ssh $USERNAME@localhost -p $SSH_PORT"
                read -p "Press any key to continue..."
                ;;
            3)
                customize_settings
                ;;
            4)
                service_menu
                ;;
            5)
                manage_service status
                read -p "Press any key to continue..."
                ;;
            6)
                pkill -f "qemu-system-x86_64" 2>/dev/null || true
                echo "[SUCCESS] All VM instances stopped!"
                read -p "Press any key to continue..."
                ;;
            7)
                echo "[INFO] Exiting to terminal..."
                exit 0
                ;;
            8)
                echo "[INFO] Starting with default settings..."
                break
                ;;
            *)
                echo "[ERROR] Invalid option!"
                sleep 1
                ;;
        esac
    done
}

# Service Sub-Menu
service_menu() {
    while true; do
        show_banner
        echo "════════════════ 24/7 Service Management ════════════════"
        echo "1) Install & Enable 24/7 Service"
        echo "2) Start Service Now"
        echo "3) Stop Service"
        echo "4) Check Service Status"
        echo "5) Disable Auto-start"
        echo "6) Return to Main Menu"
        echo ""
        
        read -p "Select option (1-6): " choice
        
        case $choice in
            1)
                manage_service create
                manage_service enable
                read -p "Press any key to continue..."
                ;;
            2)
                manage_service start
                read -p "Press any key to continue..."
                ;;
            3)
                manage_service stop
                read -p "Press any key to continue..."
                ;;
            4)
                manage_service status
                read -p "Press any key to continue..."
                ;;
            5)
                manage_service disable
                read -p "Press any key to continue..."
                ;;
            6)
                return
                ;;
            *)
                echo "[ERROR] Invalid option!"
                sleep 1
                ;;
        esac
    done
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
        4) read -p "New Memory (e.g., 8G): " MEMORY ;;
        5) read -p "New CPU Cores: " CPUS ;;
        6) read -p "New Disk Size (e.g., 40G): " DISK_SIZE ;;
        7) read -p "New SSH Port: " SSH_PORT ;;
        8) read -p "New Swap Size (0G to disable): " SWAP_SIZE ;;
        9)
            echo "[INFO] Settings saved!"
            return
            ;;
        *)
            echo "[ERROR] Invalid option!"
            sleep 1
            ;;
    esac
    
    # Save to config file
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
    
    echo "[SUCCESS] Configuration saved!"
    sleep 1
}

# Load saved config
load_config() {
    if [ -f "$VM_DIR/vm.config" ]; then
        source "$VM_DIR/vm.config"
        echo "[INFO] Loaded saved configuration"
    fi
}

# Parse command line arguments
parse_args() {
    case "$1" in
        --menu|--interactive|-m)
            show_menu
            ;;
        --service|-s)
            if [ -n "$2" ]; then
                manage_service "$2"
                exit 0
            else
                echo "Usage: $0 --service [create|start|stop|status|enable|disable]"
                exit 1
            fi
            ;;
        --background|--daemon|-b)
            BACKGROUND_MODE=1
            ;;
        --stop)
            pkill -f "qemu-system-x86_64" 2>/dev/null || true
            echo "[INFO] All QEMU instances stopped"
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "QEMU-freeroot VM Manager"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --menu, -m        Show interactive menu with ALBIN banner"
    echo "  --background, -b  Start VM in background (24/7 mode)"
    echo "  --service, -s     Manage 24/7 systemd service"
    echo "                    [create|start|stop|status|enable|disable]"
    echo "  --stop            Stop all running VM instances"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                 # Start VM normally"
    echo "  $0 --menu          # Show interactive menu"
    echo "  $0 --background    # Run in 24/7 background mode"
    echo "  $0 --service start # Start 24/7 service"
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
  - if [ "$SWAP_SIZE" -eq 0 ]; then
      on_swap
    fi
    
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
if [ -z "${BACKGROUND_MODE:-}" ]; then
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
    echo "[INFO] Starting VM in 24/7 background mode..."
    echo "[INFO] VM will continue running even when you close terminal"
    echo "[INFO] SSH: ssh $USERNAME@localhost -p $SSH_PORT"
    eval $QEMU_CMD
    echo "[SUCCESS] VM is now running in background!"
    echo "[INFO] To stop: ./vm.sh --service stop"
    exit 0
else
    echo "[INFO] Starting VM in interactive mode..."
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
