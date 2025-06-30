# This function will generate the MCP server executables and the JSON configuration.
# It needs access to:
# - unstablePkgsInput: The raw 'inputs.unstable' from your main flake.
# - mcpServersNixInput: The 'inputs.mcp-servers-nix' from your main flake.
# - system: The target system architecture (e.g., "x86_64-linux").
{
  unstablePkgsInput,
  mcpServersNixInput,
  system ? "x86_64-linux",
  user ? "jevin",
}: let
  # pkgs instance from 'unstable' *with* the mcp-servers-nix overlay.
  # This is used to access the actual server packages like 'pkgs.mcp-server-time'.
  pkgs_for_mcp_executables = import unstablePkgsInput {
    inherit system;
    config.allowUnfree = true; # Maintain existing config
    overlays = [mcpServersNixInput.overlays.default];
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

          subPackages = ["cmd/cli" "cmd/mcp"];

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

          meta =
            oldAttrs.meta
            // {
              description = "Kubernetes CRD controller that manages the lifecycle of CNCF Flux CD with MCP server support";
            };
        });
      })
    ];
  };

  # Create wrapper for mcp-server-time with proper timezone data access
  timeWrapper =
    pkgs_for_mkconfig.runCommand "mcp-server-time-wrapper" {
      buildInputs = [pkgs_for_mkconfig.makeWrapper];
    } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs_for_mcp_executables.mcp-server-time}/bin/mcp-server-time $out/bin/mcp-server-time-wrapper \
        --set PYTHONPATH "${pkgs_for_mkconfig.python3Packages.tzdata}/${pkgs_for_mkconfig.python3.sitePackages}" \
        --set TZDIR "${pkgs_for_mkconfig.tzdata}/share/zoneinfo" \
        --add-flags "--local-timezone America/Toronto"
    '';

  # Create wrapper for mcp-server-git
  gitWrapper =
    pkgs_for_mkconfig.runCommand "mcp-server-git-wrapper" {
      buildInputs = [pkgs_for_mkconfig.makeWrapper];
    } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs_for_mcp_executables.mcp-server-git}/bin/mcp-server-git $out/bin/mcp-server-git-wrapper \
        --prefix PATH : ${pkgs_for_mkconfig.git}/bin
    '';

  # Flux MCP Server wrapper using makeWrapper
  fluxMcpWrapper =
    pkgs_for_mkconfig.runCommand "run-flux-operator-mcp" {
      buildInputs = [pkgs_for_mkconfig.makeWrapper];
    } ''
      mkdir -p $out/bin
      makeWrapper ${pkgs_for_mkconfig.fluxcd-operator}/bin/flux-operator-mcp $out/bin/run-flux-operator-mcp \
        --add-flags "serve" \
        --set KUBECONFIG "/home/${user}/.kube/config"
    '';

  # myfitnesspal-mcp package definition (revised)
  myfitnesspalMcpPkg = pkgs_for_mkconfig.callPackage (
    {
      lib,
      stdenv,
      python3,
      fetchFromGitHub,
      makeWrapper,
      python3Packages,
    }: let
      pythonEnv = python3.withPackages (ps:
        with ps; [
          fastapi # uvicorn is a dependency of fastapi
          mcp # Assuming pkgs_for_mkconfig.python3Packages.mcp based on mcp>=1.9.1 in pyproject.toml
          myfitnesspal
          browser-cookie3
        ]);
    in
      stdenv.mkDerivation rec {
        pname = "myfitnesspal-mcp";
        version = "0.1.0"; # Or "unstable-YYYY-MM-DD"

        src = fetchFromGitHub {
          owner = "jevy";
          repo = "myfitnesspal-mcp";
          rev = "main";
          # IMPORTANT: Replace this placeholder hash with the actual hash after running nix-prefetch-url or a build attempt.
          hash = "sha256-Hxhb64UOgM8DPBtBJNCka0aRKO5GgZjdB4haWN+XLVk=";
        };

        nativeBuildInputs = [makeWrapper]; # makeWrapper is a build-time tool

        buildPhase = ''
          echo "Custom buildPhase: Doing nothing here, setup is in installPhase."
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/bin
          mkdir -p $out/lib/python-site-packages

          # Copy the application code
          cp -R ${src}/src/nutrition_coach $out/lib/python-site-packages/nutrition_coach

          # Create the wrapper script
          makeWrapper ${pythonEnv}/bin/uvicorn $out/bin/myfitnesspal-mcp-server \
            --set PYTHONPATH "$out/lib/python-site-packages:${pythonEnv}/${python3.sitePackages}" \
            --set MYFITNESSPAL_COOKIE_FILE "/home/jevin/myfitnesspal_cookies.txt" \
            --add-flags "nutrition_coach.api_server:app --host 0.0.0.0 --port 9087"

          runHook postInstall
        '';

        doCheck = false;

        meta = with lib; {
          description = "MCP server for MyFitnessPal (custom stdenv build)";
          homepage = "https://github.com/jevy/myfitnesspal-mcp";
          license = licenses.asl20; # Verify actual license
          maintainers = []; # User to fill
          platforms = platforms.linux;
        };
      }
  ) {};
  # Wrapper for github-mcp-server to inject sops secret
  githubMcpPkg = pkgs_for_mkconfig.buildGoModule rec {
    pname = "github-mcp-server";
    version = "unstable-2024-05-22";

    src = pkgs_for_mkconfig.fetchFromGitHub {
      owner = "github";
      repo = "github-mcp-server";
      rev = "main";
      hash = "sha256-DZi1kYm78r7GxF3v16pdQZrMxWPq/0iI+qXSh7QCwAA=";
    };

    vendorHash = "sha256-GYfK5QQH0DhoJqc4ynZBWuhhrG5t6KoGpUkZPSfWfEQ=";

    subPackages = ["cmd/github-mcp-server"];

    ldflags = ["-s" "-w"];

    nativeBuildInputs = [pkgs_for_mkconfig.makeWrapper];

    postInstall = ''
      # Move the original binary to avoid a name conflict
      mv $out/bin/github-mcp-server $out/bin/github-mcp-server-real

      # Create a new wrapper script that will be executed by the MCP client
      cat > $out/bin/run-github-mcp-server <<EOF
      #!/bin/sh
      # Export the token by reading the secret file at runtime, when this script is called
      export GITHUB_PERSONAL_ACCESS_TOKEN="\$(cat /run/user/1000/secrets/github_personal_access_token)"
      # Execute the actual server binary, passing through all arguments
      exec "$out/bin/github-mcp-server-real" "\$@"
      EOF

      # Make the new wrapper script executable
      chmod +x $out/bin/run-github-mcp-server
    '';

    meta = with pkgs_for_mkconfig.lib; {
      description = "GitHub MCP Server built from source";
      homepage = "https://github.com/github/github-mcp-server";
      license = licenses.mit; # As per repository
      maintainers = [];
    };
  };
in {
  # Package containing the wrapped MCP server executables
  default = pkgs_for_mkconfig.buildEnv {
    name = "mcp-server-executables";
    paths = [
      timeWrapper
      gitWrapper
      fluxMcpWrapper
      myfitnesspalMcpPkg
      githubMcpPkg
    ];
  };

  # The generated JSON configuration file derivation
  generatedMcpConfig = mcpServersNixInput.lib.mkConfig pkgs_for_mkconfig {
    programs = {
      # Disable the built-in modules since we're using custom wrappers
      time.enable = true;
      git.enable = true;
      github.enable = false; # Keep this disabled to avoid conflicts
      # TODO add (as per your original mcp/flake.nix)
      # Obsidian
    };
    flavor = "claude";
    fileName = "mcp_settings.json";
    settings = {
      servers = let
        kubernetesWrapper =
          pkgs_for_mkconfig.runCommand "run-mcp-kubernetes" {
            buildInputs = [pkgs_for_mkconfig.makeWrapper];
          } ''
            mkdir -p $out/bin
            makeWrapper ${pkgs_for_mkconfig.lib.getExe' pkgs_for_mkconfig.nodejs "npx"} $out/bin/run-mcp-kubernetes \
              --add-flags "-y" \
              --add-flags "mcp-server-kubernetes" \
              --prefix PATH : ${pkgs_for_mkconfig.nodejs}/bin
          '';
      in {
        # Use our custom wrappers instead of the built-in modules
        "github" = {
          command = "${githubMcpPkg}/bin/run-github-mcp-server";
          args = ["stdio"];
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
          args = ["--verbose"];
        };
        "flux-operator-mcp" = {
          command = "${fluxMcpWrapper}/bin/run-flux-operator-mcp";
          args = [];
        };
        "myfitnesspal-mcp" = {
          command = "${myfitnesspalMcpPkg}/bin/myfitnesspal-mcp-server";
          # args are hardcoded in the package's postInstall
          args = [];
        };
      };
    };
  };
}
