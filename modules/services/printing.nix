# Printing (CUPS, Avahi, printer setup)
{ ... }:
{
  flake.modules.nixos.printing =
    { pkgs, ... }:
    {
      services.printing = {
        enable = true;
        # Don't run cups-browsed: the printer is declared explicitly below, and
        # cups-browsed would otherwise auto-create a redundant DNS-SD queue
        # (Brother_HL_L3270CDW_series, implicitclass://). Jobs land on that
        # duplicate, and a single filter error trips stop-printer, disabling it
        # and making printing appear broken while the real queue sits idle.
        browsed.enable = false;
      };

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      # The unit sets no RuntimeDirectory, so /run/avahi-daemon survives a
      # restart. If the daemon dies without unlinking its PID file (shutdown,
      # suspend, SIGKILL), the next start fails with "Failed to create PID file:
      # File exists" (exit 255) — a failed unit at the end of nixos-rebuild
      # switch. avahi tries to clear the stale file itself and can't: the unit's
      # CapabilityBoundingSet drops CAP_DAC_OVERRIDE, and /run/avahi-daemon is
      # owned by the avahi user with mode 0755, so root can't unlink inside it.
      # Hence the "+" prefix — it runs the cleanup with full privileges outside
      # the sandbox. Plain (or "-"-only) ExecStartPre hits the same EACCES.
      systemd.services.avahi-daemon.serviceConfig.ExecStartPre = [
        "+-${pkgs.coreutils}/bin/rm -f /run/avahi-daemon/pid"
      ];

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
