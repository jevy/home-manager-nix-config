# sms-backup-md: Convert Android "SMS Backup & Restore" XML exports to Markdown.
#
# Bundles three repos that expect to be sibling directories:
#   - sms_backup_md (main script)
#   - message_md    (shared message/markdown library)
#   - hal           (person/contact model)
#
# Patches applied to fix upstream bugs and packaging issues:
#   1. sys.path inserts rewritten from relative ("../hal/") to absolute nix store paths
#   2. message_md RESOURCES_FOLDER hardcoded to "../../github/message_md/resources"
#      -> patched to $out/lib/.../message_md/resources
#   3. Typo: "folder_per_erson" -> "folder_per_person" (config.py)
#   4. load_groups() returns len() which is 0/falsy for empty groups -> return True
#   5. XMLParser: added recover=True to handle base64 MMS attachments that exceed
#      libxml2 2.15+'s attribute buffer size limit (~1GB)
#   6. mms.find(MMS_ADDRS) and mms.find(MMS_PARTS) can return None when parser
#      recovers from truncated elements -> guarded with "or []"
#   7. address_type unbound when MMS has no addr children -> initialized to None
#
# Usage:
#   1. Create config/ dir with people.json and groups.json (see message_md docs)
#   2. sms-backup-md -m <your-slug> -c config -f <backup.xml> -o <output-dir>
#   Output: People/<slug>/<date>.md per conversation + extracted media attachments
{
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
}:

let
  pythonEnv = python3Packages.python.withPackages (ps: [
    ps.lxml
  ]);

  hal = fetchFromGitHub {
    owner = "thephm";
    repo = "hal";
    rev = "4bcffb66524c0d6929fbb695f9151cb6eeb3a020";
    hash = "sha256-IfVMQhFtoNJ0K6bW5KbCr00ApYIEN3Z2KvsuSK1lE5k=";
  };

  message_md = fetchFromGitHub {
    owner = "thephm";
    repo = "message_md";
    rev = "adca99c7965ba15c951ac2105eb2070596663daa";
    hash = "sha256-xColRfwtyQvXTabDH30nitH1hNBxFEg7mRTNaP/SGbo=";
  };

  sms_backup_md = fetchFromGitHub {
    owner = "thephm";
    repo = "sms_backup_md";
    rev = "2a430c2a7542ffab65bf468a8dac28a44d0a554d";
    hash = "sha256-+37vfPp8z08FQkohg76sutZ7lT6N1yOSbyj6olVTEwU=";
  };
in
python3Packages.buildPythonApplication {
  pname = "sms-backup-md";
  version = "0-unstable-2025-02-02";

  src = sms_backup_md;

  format = "other";

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # The project expects hal/ and message_md/ as sibling directories.
  # We lay them out as: lib/sms-backup-md/{hal,message_md,sms_backup_md}/
  # and patch the sys.path.insert calls to point there.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/sms-backup-md $out/bin

    cp -r ${hal} $out/lib/sms-backup-md/hal
    cp -r ${message_md} $out/lib/sms-backup-md/message_md
    cp -r $src $out/lib/sms-backup-md/sms_backup_md
    chmod -R u+w $out/lib/sms-backup-md

    # Patch sys.path inserts in sms_backup_md.py to use absolute paths
    substituteInPlace $out/lib/sms-backup-md/sms_backup_md/sms_backup_md.py \
      --replace-fail "sys.path.insert(1, '../hal/')" \
        "sys.path.insert(1, '$out/lib/sms-backup-md/hal')" \
      --replace-fail "sys.path.insert(1, '../message_md/')" \
        "sys.path.insert(1, '$out/lib/sms-backup-md/message_md')" \
      --replace-fail "p = XMLParser(huge_tree=True)" \
        "p = XMLParser(huge_tree=True, recover=True)" \
      --replace-fail "for addr in mms.find(MMS_ADDRS):" \
        "for addr in (mms.find(MMS_ADDRS) or []):" \
      --replace-fail "for child in mms.find(MMS_PARTS):" \
        "for child in (mms.find(MMS_PARTS) or []):"

    # Fix unbound address_type variable when MMS has no addresses
    sed -i 's/^    phone_numbers = \[\]/    address_type = None\n    phone_numbers = []/' \
      $out/lib/sms-backup-md/sms_backup_md/sms_backup_md.py

    # Patch sys.path inserts and hardcoded resource path in message_md's config.py
    substituteInPlace $out/lib/sms-backup-md/message_md/config.py \
      --replace-fail "sys.path.insert(1, '../hal/')" \
        "sys.path.insert(1, '$out/lib/sms-backup-md/hal')" \
      --replace-fail "RESOURCES_FOLDER = \"../../github/message_md/resources\"" \
        "RESOURCES_FOLDER = \"$out/lib/sms-backup-md/message_md/resources\"" \
      --replace-fail "folder_per_erson" "folder_per_person" \
      --replace-fail "return len(self.groups)" "return True"

    makeWrapper ${pythonEnv}/bin/python $out/bin/sms-backup-md \
      --add-flags "$out/lib/sms-backup-md/sms_backup_md/sms_backup_md.py"

    runHook postInstall
  '';

  meta = {
    description = "Convert SMS Backup & Restore XML backups to Markdown files";
    homepage = "https://github.com/thephm/sms_backup_md";
    license = python3Packages.lib.licenses.mit;
    mainProgram = "sms-backup-md";
  };
}
