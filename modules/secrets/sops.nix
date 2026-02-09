# Sops-nix secrets management
{ inputs, ... }:
{
  flake.modules.homeManager.sops =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        defaultSopsFile = ../../secrets.yaml;

        secrets = {
          # AI API keys
          openrouter_api_key = { };
          openai_api_key = { };
          anthropic_api_key = { };
          gemini_api_key = { };

          # Service tokens
          github_personal_access_token = { };
          grafana_homelab_secret = { };
          n8n_api_key = { };
          obsidian_api_key = { };

          # Backup
          restic_password = { };
        };
      };
    };
}
