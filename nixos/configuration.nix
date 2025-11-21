# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  inputs,
  ...
}:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      intel-media-driver
    ];
  };

  # https://nixos.wiki/wiki/Intel_Graphics
  boot.kernelParams = [ "i915.force_probe=4626" ];

  # services.xserver.videoDrivers =  [
  #   "intel-media-driver"
  # ];

  location = {
    latitude = 45.42;
    longitude = -75.70;
  };

  services.udev.packages = with pkgs; [
    via
    qmk-udev-rules
    qFlipper
  ];

  hardware.keyboard.zsa.enable = true;
  programs.adb.enable = true;
  services.hardware.bolt.enable = true;
  services.fwupd.enable = true;
  services.upower.enable = true;
  services.ddccontrol.enable = true;
  # services.ratbagd.enable = true;

  nix = {
    # package = pkgs.nixUnstable; # or versioned attributes like nix_2_4
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraSetFlags = [
      "--accept-dns=true"
    ];
  };

  # Some kind of tailscale issue
  systemd.services.tailscaled.after = [ "systemd-networkd-wait-online.service" ];

  # Idea taken from [dreamsofcode](https://github.com/dreamsofcode-io/home-row-mods)
  services.kanata = {
    enable = true;
    keyboards = {
      internalKeyboard = {
        devices = [
          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        extraDefCfg = "process-unmapped-keys yes";
        config = ''
          (defsrc
           a s d f j k l ;
          )
          (defvar
           tap-time 150
           hold-time 200
          )
          (defalias
           a (tap-hold $tap-time $hold-time a lctl)
           s (tap-hold $tap-time $hold-time s lalt)
           d (tap-hold $tap-time $hold-time d lsft)
           f (tap-hold $tap-time $hold-time f lctl)
           j (tap-hold $tap-time $hold-time j rctl)
           k (tap-hold $tap-time $hold-time k rsft)
           l (tap-hold $tap-time $hold-time l ralt)
           ; (tap-hold $tap-time $hold-time ; rmet)
          )
          (deflayer base
           @a  @s  @d  @f  @j  @k  @l  @;
          )
        '';
      };
    };
  };
  # services.sshd.enable = true;

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [
    "zfs"
    "nfs"
  ];
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p1";
      preLVM = true;
    };
  };

  fileSystems."/mnt/synology-backup" = {
    device = "192.168.1.187:/volume1/proxmox";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };

  # https://github.com/NixOS/nixpkgs/pull/126777/files
  # Running into issues with Obisidan and syncthing. Not enough inotify available
  # boot.kernel.sysctl."fs.inotify.max_user_instances" = 2147483647;

  # services.resolved.enable = false;
  # networking.resolvconf.enable = false;
  # networking.search = [];
  # networking.nameservers = ["1.1.1.1"];
  # networking.nameservers = ["192.168.1.207"];
  networking.hostName = "framework"; # Define your hostname.
  networking.hostId = "6a7f48db";
  networking.hosts = {
    "127.0.0.1" = [ "db" ];
  };
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.enableIPv6 = false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      22
      8080 # Python connection test
      27124 # Obsidian REST for MCP
      27123 # Obsidian REST for MCP
    ];

    # interfaces = {
    #   docker0 = {
    #     allowedTCPPorts = [
    #       8080 # Python connection test
    #       27124 # Obsidian REST for MCP
    #       27123 # Obsidian REST for MCP
    #     ];
    #   };
    # };
  };

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # networking.useDHCP = true;
  networking.networkmanager.enable = true;

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jevin" ];
    package = pkgs.unstable._1password-gui;
  };

  # services.xserver.enable = true;
  # services.xserver.displayManager = {
  #   gdm.enable = true;
  #   defaultSession = "sway";
  # };
  programs.sway.enable = true;
  programs.regreet.enable = true;
  services.greetd.enable = true;
  # programs.sway.package = config.home-manager.users.jevin.wayland.windowManager.sway.package;

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    withUWSM = true;
  };

  services.hypridle = {
    enable = true;
  };

  services.logind = {
    lidSwitch = "suspend";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  # security.pam.services.swaylock = {};
  security.sudo.wheelNeedsPassword = false;

  # services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # services.xserver.displayManager.startx.enable = true;
  # services.xserver.desktopManager = {
  #   gnome.enable = true;
  # };

  # services.chrony.enable = true;
  services.timesyncd = {
    servers = [
      "0.ca.pool.ntp.org"
      "1.ca.pool.ntp.org"
    ];
    enable = true;
  };
  # services.syncthing = {
  #   enable = true;
  #   systemService = true;
  #   dataDir = "/home/jevin/syncthing";
  #   user = "jevin";
  #   group = "users";
  # };

  # https://nixos.wiki/wiki/PipeWire
  hardware.bluetooth = {
    enable = true;
  };
  services.pulseaudio = {
    enable = false;
    daemon.config = {
      flat-volumes = "no";
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    # alsa.enable = true;
    # alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  # TODO: Try enabling extra portals: https://nixos.wiki/wiki/Sway
  # For Chrome sharing and stuff
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings = {
        screencast = {
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -ro";
        };
      };
    };
  };

  # For xournaljj fix
  # https://github.com/NixOS/nixpkgs/issues/163107#issuecomment-1100569484
  environment.systemPackages = [
    pkgs.adwaita-icon-theme
    pkgs.shared-mime-info
  ];

  environment.pathsToLink = [
    "/share/icons"
    "/share/mime"
  ];

  services.dbus.enable = true;

  hardware.sane.enable = true;
  hardware.sane.drivers.scanSnap.enable = true;
  # hardware.enableAllFirmware = true;
  # hardware.enableRedistributableFirmware = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.mutableUsers = false;

  programs.zsh.enable = true;
  users.users.jevin = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "qemu-libvirtd"
      "libvirtd"
      "plugdev"
      "wheel"
      "networkmanager"
      "docker"
      "dialout"
      "audio"
      "video"
      "adbusers"
      "uinput"
    ]; # Dialout if for usb/serial access for arduino

    # `nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'`
    hashedPassword = "$6$RQ3xn2S3O1RFFqiA$e725RMH8eJgw4JJ4UnSjuzJ1Pw5lNNaFRW.9M2XCrcCJsAbWPg5qs5hzRZARiK9uastNZN9XnUGBs8yM6kdMZ0";
  };

  nix.settings.trusted-users = [
    "root"
    "jevin"
  ];
  nix.settings.download-buffer-size = 268435456;

  # users.users.tyler = {
  #   shell = pkgs.zsh;
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" "networkmanager" "docker" "dialout" "audio"]; # Dialout if for usb/serial access for arduino
  # };

  # users.users.oren = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" "networkmanager" "docker" "dialout" "audio"]; # Dialout if for usb/serial access for arduino
  # };

  # Add unstable packages: https://nixos.wiki/wiki/FAQ/Pinning_Nixpkgs
  # Be sure to change the added channel to match the actually channel below
  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;
    segger-jlink.acceptLicense = true; # For B-Parasite Proj

    permittedInsecurePackages = [
      "electron-25.9.0"
      "libsoup-2.74.3"
      "qtwebengine-5.15.19"
    ];
  };

  # Automount drives
  services.devmon.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.udisks2.mountOnMedia = true;

  programs.gnupg.agent.enable = true;

  services.languagetool = {
    enable = true;
    settings = {
      fasttextBinary = "${pkgs.fasttext}/bin/fasttext";
    };
  };
  # programs.zsh.enable = true;

  # environment.sessionVariables = {
  #   _JAVA_AWT_WM_NONREPARENTING = "1"; # For Arduino & Wayland
  #   WLR_DRM_NO_MODIFIERS        = "1"; # For external monitor issues in sway
  # };

  # virtualisation.libvirtd.enable = true;
  # virtualisation.virtualbox.host.enable = true;
  # users.extraGroups.vboxusers.members = ["jevin"];
  # virtualisation.virtualbox.host.enableExtensionPack = true;

  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
  };

  # From: https://www.reddit.com/r/VFIO/comments/p4kmxr/tips_for_single_gpu_passthrough_on_nixos/
  # Also need to update: <ioapic driver="kvm"/>
  # Enable libvirtd
  virtualisation.libvirtd = {
    enable = true;
    # onBoot = "ignore";
    # onShutdown = "shutdown";
    qemu.runAsRoot = true;
  };
  # programs.dconf.enable = true;
  # environment.systemPackages = with pkgs; [ virt-manager ];
  # environment.systemPackages = with pkgs; [ cntr ];

  # boot.kernelModules = [ "v4l2loopback" ];

  # ----- USER STUFF ------
  #
  #
  fonts = {
    packages = [
      pkgs.dejavu_fonts
      pkgs.freefont_ttf
      pkgs.gyre-fonts
      pkgs.unifont
      pkgs.nerd-fonts.meslo-lg
      pkgs.nerd-fonts.symbols-only
      pkgs.weather-icons
      pkgs.font-awesome
      pkgs.noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      serif = [
        "DejaVu Serif"
      ];
      sansSerif = [
        "DejaVu Sans"
      ];
      monospace = [
        "MesloLGS Nerd Font"
        "Symbols Nerd Font"
        "Weather Icons"
        "DejaVu Sans Mono"
      ];
      emoji = [
        "Noto Color Emoji"
        "Symbols Nerd Font"
        "Weather Icons"
        "Font Awesome 5 Free"
      ];
    };

    # Instead of hidpi
    # From: https://github.com/NixOS/nixpkgs/blob/832bdf74072489b8da042f9769a0a2fac9b579c7/nixos/modules/hardware/video/hidpi.nix
    fontconfig.antialias = true;
    fontconfig.subpixel = {
      rgba = "none";
      lcdfilter = "none";
    };
  };

  # console.earlySetup = true;
  # boot.loader.systemd-boot.consoleMode = "1";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # services.fwupd.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
  boot.kernelPackages = pkgs.linuxPackages_6_12;
}
