# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, muttdown, ... }:

{
  hardware.opengl = {
    enable = true;
    # package = pkgs.unstable.mesa.drivers;
    # package32 = pkgs.unstable.pkgsi686Linux.mesa.drivers;
  };

  # services.xserver.videoDrivers =  [
  #   "intel-media-driver"
  # ];

  location = {
    latitude = 45.42;
    longitude = -75.70;
  };

  services.udev.packages = with pkgs; [
    unstable.vial
    unstable.via
    qmk-udev-rules
    fprintd
    qflipper
  ];

  hardware.keyboard.zsa.enable = true;

  services.hardware.bolt.enable = true;
  services.fwupd.enable = true;
  # services.ratbagd.enable = true;

  nix = {
    package = pkgs.nixUnstable; # or versioned attributes like nix_2_4
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
   };

  services.tailscale.enable = true;
  networking.firewall.checkReversePath = "loose";

  # services.sshd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/nvme0n1p1";
      preLVM = true;
    };
  };

  # https://github.com/NixOS/nixpkgs/pull/126777/files
  # Running into issues with Obisidan and syncthing. Not enough inotify available
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 2147483647;

  networking.hostName = "framework"; # Define your hostname.
  networking.hostId = "6a7f48db";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.enableIPv6 = false;
  boot.kernelParams = ["ipv6.disable=1"];

  # Set your time zone.
  time.timeZone = "America/Toronto";

  hardware.video.hidpi.enable = true;

  # networking.useDHCP = true;
  # networking.interfaces.enp0s31f6.useDHCP = true;
  # networking.interfaces.wlp0s20f3.useDHCP = true;
  # networking.networkmanager.enable = true;

  programs._1password = {
    enable = true;
    # polkitPolicyOwners = ["jevin"];
  };

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = ["jevin" ];
    package = pkgs.unstable._1password-gui;
  };

  # services.xserver.enable = true;
  # services.xserver.displayManager = {
  #   gdm.enable = true;
  #   defaultSession = "sway";
  # };
  programs.sway.enable = true;
  security.pam.services.swaylock = {};
  security.sudo.wheelNeedsPassword = false;

  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # services.xserver.displayManager.startx.enable = true;
  # services.xserver.desktopManager = {
  #   gnome.enable = true;
  # };


  services.chrony.enable = true;
  services.timesyncd.enable = false;
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
  hardware.pulseaudio = {
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
  #jack.enable = true;
};

  # TODO: Try enabling extra portals: https://nixos.wiki/wiki/Sway
  # For Chrome sharing and stuff
  xdg.portal.wlr = {
    enable = true;
    settings = {
      screencast = {
        chooser_type = "simple";
        chooser_cmd = "slurp -f %o -ro";
      };
    };
  };

  services.dbus.enable = true;

  hardware.sane.enable = true;
  hardware.sane.drivers.scanSnap.enable = true;
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.mutableUsers = false;

  users.users.jevin = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "qemu-libvirtd" "libvirtd" "plugdev" "wheel" "networkmanager" "docker" "dialout" "audio" "video" "syncthing"]; # Dialout if for usb/serial access for arduino

    # `nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'`
    hashedPassword = "$6$RQ3xn2S3O1RFFqiA$e725RMH8eJgw4JJ4UnSjuzJ1Pw5lNNaFRW.9M2XCrcCJsAbWPg5qs5hzRZARiK9uastNZN9XnUGBs8yM6kdMZ0";
  };

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
  nixpkgs.overlays = [ muttdown.overlay ];
  nixpkgs.config = {
    allowBroken = true;
    allowUnfree = true;

    permittedInsecurePackages = [
      "electron-13.6.9"
    ];
  };

  programs.gnupg.agent.enable = true;

  services.dictd = {
    enable = true;
    DBs = with pkgs.dictdDBs; [ wiktionary wordnet ];
  };

  # programs.zsh.enable = true;
  programs.vim = {
    defaultEditor = true ;
    package = pkgs.vimHugeX;
  };

  environment.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1"; # For Arduino & Wayland
    WLR_DRM_NO_MODIFIERS        = "1"; # For external monitor issues in sway
  };

  # virtualisation.libvirtd.enable = true;
  # virtualisation.virtualbox.host.enable = true;
  # users.extraGroups.vboxusers.members = [ "jevin" ];
  # virtualisation.virtualbox.host.enableExtensionPack = true;

  virtualisation.docker.enable = true;

  # From: https://www.reddit.com/r/VFIO/comments/p4kmxr/tips_for_single_gpu_passthrough_on_nixos/
  # Also need to update: <ioapic driver="kvm"/>
  # Enable libvirtd
  # virtualisation.libvirtd = {
  #   enable = true;
  #   # onBoot = "ignore";
  #   # onShutdown = "shutdown";
  #   qemu.ovmf.enable = true;
  #   qemu.runAsRoot = true;
  # };
  # programs.dconf.enable = true;
  # environment.systemPackages = with pkgs; [ virt-manager ];
  environment.systemPackages = with pkgs; [ cntr ];

  boot.kernelModules = [ "v4l2loopback" ];

  # ----- USER STUFF ------
  #
  #
  fonts = {
    fonts = [
              pkgs.dejavu_fonts
              pkgs.freefont_ttf
              pkgs.gyre-fonts
              pkgs.unifont
              pkgs.meslo-lgs-nf
              pkgs.weather-icons
              pkgs.font-awesome
            ];
            fontconfig.defaultFonts.emoji = [
              "MesloLGS NF"
              "Weather Icons"
              "Font Awesome 5 Free"
            ];
            fontconfig.defaultFonts.serif = [
              "DejaVu Serif"
            ];
            fontconfig.defaultFonts.monospace = [
              "DejaVu Sans Mono"
            ];
  };



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
  system.stateVersion = "22.05"; # Did you read the comment?
  boot.kernelPackages = pkgs.linuxPackages_latest;

}

