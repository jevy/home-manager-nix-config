# This function will generate the MCP server executables and the JSON configuration.
# It needs access to:
# - unstablePkgsInput: The raw 'inputs.unstable' from your main flake.
# - mcpServersNixInput: The 'inputs.mcp-servers-nix' from your main flake.
# - system: The target system architecture (e.g., "x86_64-linux").
{ unstablePkgsInput, mcpServersNixInput, system ? "x86_64-linux" }:

let
  # pkgs instance from 'unstable' *with* the mcp-servers-nix overlay.
  # This is used to access the actual server packages like 'pkgs.mcp-server-time'.
  pkgs_for_mcp_executables = import unstablePkgsInput {
    inherit system;
    config.allowUnfree = true; # Maintain existing config
    overlays = [ mcpServersNixInput.overlays.default ];
  };

  # pkgs instance from 'unstable' *without* the mcp-servers-nix overlay.
  # This is passed as the first argument to 'mkConfig', as per mcp-servers-nix documentation.
  pkgs_for_mkconfig = import unstablePkgsInput {
    inherit system;
    config.allowUnfree = true; # Maintain existing config
    overlays = [
      # Override fluxcd-operator to include MCP server
      (final: prev: {
        fluxcd-operator = prev.fluxcd-operator.overrideAttrs (oldAttrs: {
          version = "0.20.0";
          src = prev.fetchFromGitHub {
            owner = "controlplaneio-fluxcd";
            repo = "flux-operator";
            rev = "v0.20.0";
            hash = "sha256-GGHufHUqTylgynK19aaj4KAawlzzuz3iSEHa+vVVPMM=";
          };
          
          vendorHash = "sha256-5uT/pcfXrinyJ1hXmQ+vmWNuyO33c6d5PAjm6kwOZmY=";
          
          subPackages = [ "cmd/cli" "cmd/mcp" ];
          
          ldflags = [
            "-s"
            "-w"
            "-X main.VERSION=0.20.0"
          ];
          
          env.CGO_ENABLED = "0";
          
          # Disable version check since we're updating version
          doCheck = false;
          
          postInstall = ''
            # Rename the CLI binary to flux-operator (keeping original behavior)
            mv $out/bin/cli $out/bin/flux-operator
            # Rename the MCP binary to flux-operator-mcp
            mv $out/bin/mcp $out/bin/flux-operator-mcp
          '';
          
          meta = oldAttrs.meta // {
            description = "Kubernetes CRD controller that manages the lifecycle of CNCF Flux CD with MCP server support";
          };
        });
      })
    ];
  };

  # Create wrapper for mcp-server-time with proper timezone data access
  timeWrapper = pkgs_for_mkconfig.writeShellScriptBin "mcp-server-time-wrapper" ''
    #!${pkgs_for_mkconfig.stdenv.shell}
    # Set timezone data path for Python's zoneinfo module
    export PYTHONPATH="${pkgs_for_mkconfig.python3Packages.tzdata}/${pkgs_for_mkconfig.python3.sitePackages}:$PYTHONPATH"
    # Set system timezone data as fallback
    export TZDIR="${pkgs_for_mkconfig.tzdata}/share/zoneinfo"
    # Execute the actual mcp-server-time with all arguments
    exec "${pkgs_for_mcp_executables.mcp-server-time}/bin/mcp-server-time" "$@"
  '';

  # Create wrapper for mcp-server-fetch
  fetchWrapper = pkgs_for_mkconfig.writeShellScriptBin "mcp-server-fetch-wrapper" ''
    #!${pkgs_for_mkconfig.stdenv.shell}
    exec "${pkgs_for_mcp_executables.mcp-server-fetch}/bin/mcp-server-fetch" "$@"
  '';

  # Create wrapper for mcp-server-git
  gitWrapper = pkgs_for_mkconfig.writeShellScriptBin "mcp-server-git-wrapper" ''
    #!${pkgs_for_mkconfig.stdenv.shell}
    # Ensure git is available in PATH
    export PATH="${pkgs_for_mkconfig.git}/bin:$PATH"
    exec "${pkgs_for_mcp_executables.mcp-server-git}/bin/mcp-server-git" "$@"
  '';

  # Flux MCP Server wrapper
  fluxMcpWrapper = pkgs_for_mkconfig.writeShellScriptBin "run-flux-operator-mcp" ''
    #!${pkgs_for_mkconfig.stdenv.shell}
    
    # Set default KUBECONFIG if not already set
    if [ -z "$KUBECONFIG" ]; then
      export KUBECONFIG="$HOME/.kube/config"
    fi
    
    # Execute flux-operator-mcp with serve command and any additional args
    exec ${pkgs_for_mkconfig.fluxcd-operator}/bin/flux-operator-mcp serve "$@"
  '';

in
{
  # Package containing the wrapped MCP server executables
  default = pkgs_for_mkconfig.buildEnv {
    name = "mcp-server-executables";
    paths = [
      timeWrapper
      fetchWrapper
      gitWrapper
      fluxMcpWrapper
    ];
  };

  # The generated JSON configuration file derivation
  generatedMcpConfig = mcpServersNixInput.lib.mkConfig pkgs_for_mkconfig {
    programs = {
      # Disable the built-in modules since we're using custom wrappers
      time.enable = false;
      fetch.enable = false;
      git.enable = false;
      # TODO add (as per your original mcp/flake.nix)
      # Obsidian
    };
    flavor = "claude";
    fileName = "mcp_settings.json";
    settings = {
      servers = let
        kubernetesWrapper = pkgs_for_mkconfig.writeShellScriptBin "run-mcp-kubernetes" ''
          #!${pkgs_for_mkconfig.stdenv.shell}
          # Add nodejs to PATH so npx can find node for the executed script
          export PATH="${pkgs_for_mkconfig.nodejs}/bin:$PATH"
          # Execute npx with its original arguments, passing along any arguments given to this wrapper
          exec "${pkgs_for_mkconfig.lib.getExe' pkgs_for_mkconfig.nodejs "npx"}" -y mcp-server-kubernetes "$@"
        '';
      in {
        # Use our custom wrappers instead of the built-in modules
        "fetch" = {
          command = "${fetchWrapper}/bin/mcp-server-fetch-wrapper";
          args = [];
        };
        "git" = {
          command = "${gitWrapper}/bin/mcp-server-git-wrapper";
          args = [];
        };
        "time" = {
          command = "${timeWrapper}/bin/mcp-server-time-wrapper";
          args = [];
        };
        "mcp-server-kubernetes" = {
          command = "${kubernetesWrapper}/bin/run-mcp-kubernetes";
          args = [ "--verbose" ];
        };
        "flux-operator-mcp" = {
          command = "${fluxMcpWrapper}/bin/run-flux-operator-mcp";
          args = [];
          env = {
            # KUBECONFIG will be set by the wrapper if not already present
          };
        };
      };
    };
  };
}