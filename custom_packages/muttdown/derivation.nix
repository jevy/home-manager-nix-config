{ lib, python3, fetchFromGitHub }:

python3.pkgs.buildPythonApplication rec {
  pname = "muttdown";
  version = "0.3.5";

  src = python3.pkgs.fetchPypi {
    inherit pname version;
    sha256 = "VntqvZmGYB/uugmf1BRcFCDKab6fdHqVKuY+Cg81E5A=";
  };

  propagatedBuildInputs =
    with python3.pkgs; [
      pyyaml
      markdown
      (
        buildPythonPackage rec {
          pname = "pyliner";
          version = "0.8.0";
          propagatedBuildInputs = [ cssutils beautifulsoup4 ];
          src = fetchFromGitHub {
            owner = "rennat";
            repo = "pynliner";
            rev = "0.8.0";
            sha256 = "C+IYcKO6BGwLLNApn7Z4/X7a0NZOqUEZH2RR02EwVVg=";
          };
          doCheck = false;
        }

      )

    ];

  checkPhase = ''
    runHook preCheck
    ${python3.interpreter} -m unittest
    runHook postCheck
  '';

  meta = with lib; {
    description = "A sendmail replacement for mutt allowing the user write markdown to send in HTML format";
    homepage    = "https://github.com/Roguelazer/muttdown";
    license     = licenses.isc;
    platforms   = platforms.linux;
    maintainers = [ maintainers.jevy ];
  };
}

