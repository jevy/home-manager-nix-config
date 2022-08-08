# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  hardware.opengl = {
    enable = true;
  };

  # services.xserver.videoDrivers =  [
  #   "intel-media-driver"
  # ];

  location = {
    latitude = 45.42;
    longitude = -75.70;
  };

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 80;
      STOP_CHARGE_THRESH_BAT0 = 90;
      WIFI_PWR_ON_AC = "on";
      USB_AUTOSUSPEND = 0;
    };
  };
  services.power-profiles-daemon.enable = false;

  hardware.keyboard.zsa.enable = true;

  services.hardware.bolt.enable = true;
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

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  #
  # https://discourse.nixos.org/t/system-with-nixos-how-to-add-another-extra-distribution/5767/7
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "America/Toronto";

  # networking.useDHCP = true;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp0s20f3.useDHCP = true;
  networking.networkmanager.enable = true;

  programs._1password = {
    enable = true;
    gid = 5001;
    # polkitPolicyOwners = ["jevin" "jevinhumi"];
  };

  programs._1password-gui = {
    enable = true;
    gid = 5000;
    polkitPolicyOwners = ["jevin" "jevinhumi"];
  };

  # services.xserver.enable = true;
  # services.xserver.displayManager = {
  #   gdm.enable = true;
  #   defaultSession = "sway";
  # };
  # programs.sway.enable = true;
  security.pam.services.swaylock = {};

  # services.xserver.displayManager.startx.enable = true;
  # services.xserver.desktopManager = {
  #   gnome.enable = true;
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  # Jevin - To add the printer; 1. `nix-shell -p hplip` 2. hp-makeuri <IP> 3. Add that URL to cups

  services.chrony.enable = true;
  services.timesyncd.enable = false;

  # https://nixos.wiki/wiki/PipeWire
  hardware.bluetooth = {
    enable = true;
  };
  services.blueman.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    pulse.enable = true;
  };
  services.actkbd.enable = true;

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
  ## services.dbus.enable = true;

  hardware.sane.enable = true;
  hardware.sane.drivers.scanSnap.enable = true;
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.overlays = [
    (
      self: super:
      {
        rofi-with-plugins = self.rofi.override { plugins = [ pkgs.rofi-calc ]; };
      }
    )
  ];
  # services.sdrplayApi.enable = true;
  # nixpkgs.overlays = [
  #   (
  #     self: super:
  #     {
  #       soapysdr-with-plugins = self.soapysdr.override { extraPackages = [ self.soapysdrplay ]; };
  #       sdrpp-with-sdrplay = self.sdrpp.override { sdrplay_source= true; };
  #     }
  #   )
  #   # Zoom screen sharing
  #   (
  #     self: super:
  #     {
  #      zoomUsFixed = pkgs.zoom-us.overrideAttrs (old: {
  #       postFixup = old.postFixup + ''
  #       wrapProgram $out/bin/zoom-us --unset XDG_SESSION_TYPE
  #     '';});
  #        zoom = pkgs.zoom-us.overrideAttrs (old: {
  #     postFixup = old.postFixup + ''
  #       wrapProgram $out/bin/zoom --unset XDG_SESSION_TYPE
  #     '';});
  #     }
  #     )
  # ];

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  users.mutableUsers = false;

  users.users.jevin = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "qemu-libvirtd" "libvirtd" "plugdev" "wheel" "networkmanager" "docker" "dialout" "audio" "video"]; # Dialout if for usb/serial access for arduino

    # `nix-shell -p mkpasswd --run 'mkpasswd -m sha-512'`
    hashedPassword = "$6$RQ3xn2S3O1RFFqiA$e725RMH8eJgw4JJ4UnSjuzJ1Pw5lNNaFRW.9M2XCrcCJsAbWPg5qs5hzRZARiK9uastNZN9XnUGBs8yM6kdMZ0";
  };

  users.users.jevinhumi = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "plugdev" "wheel" "networkmanager" "docker" "dialout" "audio" "video"]; # Dialout if for usb/serial access for arduino

    hashedPassword = "$6$aw5LoOsiqpalwsvN$NvzZMxYQoBU.uKE6LUG5algVkjp9QoRcRg3EPNL2/zbRH4WAYII5VDu7hgj59Kmjt0lwQ5Vf.lvoALh4fvfik/";
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
  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      unstable = import <nixos-unstable> {
        config = config.nixpkgs.config;
      };
    };


    permittedInsecurePackages = [
      "electron-13.6.9"
    ];
  };

  programs.gnupg.agent.enable = true;

  # programs.zsh.enable = true;
  programs.vim = {
    defaultEditor = true ;
    package = pkgs.vimHugeX;
  };


  #programs.sway = {
  #  enable = true;
  #  wrapperFeatures.gtk = true; # so that gtk works properly
  #  extraPackages = with pkgs; [
  #    swaylock
  #    swayidle
  #    waybar
  #    wl-clipboard
  #    mako # notification daemon
  #    rofi-with-plugins
  #    #wofi
  #    wlsunset
  #    pamixer
  #    grim
  #    swappy
  #    slurp
  #    clipman
  #    brightnessctl
  #    autotiling
  #    wdisplays
  #    copyq
  #    kooha
  #    wf-recorder
  #    jq # For waybar weather

  #    gst_all_1.gst-plugins-good # For kooha
  #  ];
  #};

  environment.sessionVariables = {
    _JAVA_AWT_WM_NONREPARENTING = "1"; # For Arduino & Wayland
    WLR_DRM_NO_MODIFIERS = "1"; # For external monitor issues in sway
  };


  # virtualisation.libvirtd.enable = true; 
  # virtualisation.virtualbox.host.enable = true;
  # users.extraGroups.vboxusers.members = [ "jevin" "jevinhumi" ];
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
  # boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
  # boot.kernelModules = [ "kvm-intel" "vfio-pci" ];

  # If I want to have this loaded properly at autoload
  # https://github.com/NixOS/nixpkgs/commit/1c58cdbeed880e99d816c234a954d4cdfc073b6c
  # sudo modprobe v4l2loopback
  # See it the right options were called: 
  # From https://serverfault.com/a/521751
  # $ nix-shell -p sysfsutils
  # $ systool -vm v4l2loopback
  # For webcam background rewriting
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 exclusive_caps=1 video_nr=2 card_label="fake-cam"
  '';


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
  boot.kernelPackages = pkgs.linuxPackages_5_18;

}

