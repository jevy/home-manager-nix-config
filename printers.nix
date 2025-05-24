{
  config,
  pkgs,
  ...
}: {
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [pkgs.hplip pkgs.brlaser pkgs.cups-brother-hll3230cdw];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Jevin - If need to regenerate the deviceUri: To add the printer; 1. `nix-shell -p hplip` 2. hp-makeuri <IP> 3. Add that URL to cups
  # Model = `lminfo -m`
  hardware.printers.ensurePrinters = [
    # {
    #   model = "drv:///hp/hpcups.drv/hp-officejet_pro_9010_series.ppd";
    #   deviceUri = "hp:/net/HP_OfficeJet_Pro_9010_series?ip=192.168.1.76";
    #   location = "Basement";
    #   name = "HP_Officejet_Pro_9010";
    # }
    # {
    #   model = "everywhere";
    #   deviceUri = "ipp://192.168.3.225/ipp";
    #   location = "Basement";
    #   name = "BrotherHL_L3270CDW";
    # }
  ];
}
