# Printing (CUPS, Avahi, printer setup)
{ ... }:
{
  flake.modules.nixos.printing =
    { ... }:
    {
      services.printing = {
        enable = true;
      };

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      # Brother HL-L3270CDW: driverless via IPP Everywhere (verified: IPP 2.0,
      # URF + PWG raster, duplex, color). No vendor driver/PPD needed.
      # If the printer's IP changes, update deviceUri — verify the endpoint with:
      #   ipptool -tv ipp://<IP>/ipp/print get-printer-attributes.test
      hardware.printers = {
        ensurePrinters = [
          {
            name = "Brother_HL-L3270CDW";
            description = "Brother HL-L3270CDW";
            deviceUri = "ipp://192.168.1.13/ipp/print";
            model = "everywhere";
            ppdOptions = {
              PageSize = "Letter";
              Duplex = "DuplexNoTumble";
            };
          }
        ];
        ensureDefaultPrinter = "Brother_HL-L3270CDW";
      };
    };
}
