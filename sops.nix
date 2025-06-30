# { config,
# }:
{
  sops = {
    age.keyFile = "/home/jevin/.config/sops/age/keys.txt"; # must have no password!

    defaultSopsFile = ./secrets.yaml;
    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";

    secrets.openai_api_key = {
      # sopsFile = ./secrets.yml.enc; # optionally define per-secret files
      path = "${defaultSymlinkPath}/openai_api_key";
    };
    secrets.github_personal_access_token = {
      path = "${defaultSymlinkPath}/github_personal_access_token";
    };
  };
}
