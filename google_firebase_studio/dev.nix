{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"
  
  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.unzip
    pkgs.openssh
    pkgs.git
    pkgs.qemu_kvm
    pkgs.sudo
    pkgs.cdrkit
    pkgs.cloud-utils
    pkgs.qemu
    pkgs.systemd  # Added for 24/7 service support
    pkgs.gnused   # Added for configuration management
    pkgs.coreutils # Enhanced core utilities
  ];
  
  # Sets environment variables in the workspace
  env = {
    # Enable systemd user services
    XDG_RUNTIME_DIR = "/run/user/$(id -u)";
    # Set terminal for interactive menu
    TERM = "xterm-256color";
  };
  
  # Enable systemd user services
  systemd.user = {
    enable = true;
    services = {
      # Auto-start ssh agent
      ssh-agent = {
        enable = true;
        serviceConfig = {
          Type = "forking";
          ExecStart = "${pkgs.openssh}/bin/ssh-agent -a %t/ssh-agent.socket";
        };
        socketConfig.SocketMode = "0600";
      };
    };
  };
  
  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      # Runs when a workspace is first created with this `dev.nix` file
      onCreate = {
        # Enable systemd user services
        setup-systemd = "systemctl --user enable ssh-agent";
        start-systemd = "systemctl --user start ssh-agent";
        # Set up QEMU permissions
        qemu-setup = "sudo chmod 666 /dev/kvm 2>/dev/null || true";
      };
      # To run something each time the workspace is (re)started, use the `onStart` hook
      onStart = {
        # Start systemd services
        start-services = "systemctl --user start ssh-agent";
        # Show welcome message
        welcome = "echo 'QEMU-freeroot with 24/7 VPS mode ready! Use: ./vm.sh --menu'";
      };
    };

    # Disable previews completely
    previews = {
      enable = false;
    };
  };
}
