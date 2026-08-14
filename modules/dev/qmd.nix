# QMD — local CLI for hybrid BM25 + vector search over markdown files
# Embeddings and models stored in ~/.cache/qmd/ (default XDG cache)
#
# Systemd timer re-indexes and embeds every 6 hours so the index and vectors
# stay fresh.
{ inputs, ... }:
{
  flake.modules.homeManager.qmd =
    { pkgs, lib, ... }:
    let
      # Upstream's wrapper sets LD_LIBRARY_PATH with makeWrapper's `--set`,
      # which CLOBBERS whatever the caller exported — so vulkan-loader cannot
      # be added from the outside (an outer wrapper is overwritten by the inner
      # one, and `--prefix` on a re-wrap loses the same race). Patch the
      # generated wrapper script directly instead.
      #
      # Without this, node-llama-cpp's bundled @node-llama-cpp/linux-x64-vulkan
      # backend is present but its .so cannot dlopen libvulkan.so.1, so qmd
      # silently falls back to CPU. On this laptop (Radeon 860M, 22 GB usable
      # VRAM) that is the difference between a ~18s and a ~44s cold rerank.
      # Verify with `qmd doctor` — it should report "GPU vulkan; offloading
      # enabled". Note `qmd status` no longer shows the Device block as of
      # 2.6.x; that moved to `qmd doctor`.
      qmd = inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          substituteInPlace $out/bin/qmd \
            --replace-fail "export LD_LIBRARY_PATH='" \
                           "export LD_LIBRARY_PATH='${lib.makeLibraryPath [ pkgs.vulkan-loader ]}:"
        '';
      });
    in
    {
      home.packages = [ qmd ];

      systemd.user.services.qmd-embed = {
        Unit.Description = "QMD: re-index collections and generate embeddings";
        Service = {
          Type = "oneshot";
          ExecStart = toString (pkgs.writeShellScript "qmd-update-embed" ''
            ${qmd}/bin/qmd update
            ${qmd}/bin/qmd embed
          '');
        };
      };

      systemd.user.timers.qmd-embed = {
        Unit.Description = "Run QMD embed every 6 hours";
        Timer = {
          OnCalendar = "*-*-* 00/6:00:00";
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
