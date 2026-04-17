# Ranger file manager configuration
{ ... }:
{
  flake.modules.homeManager.ranger =
    { pkgs, ... }:
    let
      rangerArchives = pkgs.fetchFromGitHub {
        owner = "maximtrp";
        repo = "ranger-archives";
        rev = "4085d338b87c3e6cb5f90b532740bff3a18f68ac";
        sha256 = "sha256-D1w+RsorEoZx91r8Wb8RvNMgLhikflA4uG2jgcRZhGc=";
      };
    in
    {
      home.packages = [ pkgs.ranger ];

      home.file.".config/ranger/plugins/ranger-archives".source = rangerArchives;

      home.file.".config/ranger/rc.conf".text = ''
        setlocal path=~/Downloads sort mtime
        map <C-f> fzf_select

        # Ranger-archives plugin
        map ex extract
        map ec compress

        # Drag drop
        map <C-d> shell ripdrag -a -x %p
      '';

      home.file.".config/ranger/commands.py".text = ''
        from __future__ import (absolute_import, division, print_function)
        import os
        from ranger.api.commands import Command


        class fzf_select(Command):
            """
            :fzf_select
            Find a file using fzf.
            With a prefix argument select only directories.
            """
            def execute(self):
                import subprocess
                if self.quantifier:
                    command="find -L . \( -path '*/\.*' -o -fstype 'dev' -o -fstype 'proc' \) -prune \
                    -o -type d -print 2> /dev/null | sed 1d | cut -b3- | fzf +m"
                else:
                    command="find -L . \( -path '*/\.*' -o -fstype 'dev' -o -fstype 'proc' \) -prune \
                    -o -print 2> /dev/null | sed 1d | cut -b3- | fzf +m"
                fzf = self.fm.execute_command(command, stdout=subprocess.PIPE)
                stdout, stderr = fzf.communicate()
                if fzf.returncode == 0:
                    fzf_file = os.path.abspath(stdout.decode('utf-8').rstrip('\n'))
                    if os.path.isdir(fzf_file):
                        self.fm.cd(fzf_file)
                    else:
                        self.fm.select_file(fzf_file)


        class fzf_locate(Command):
            """
            :fzf_locate
            Find a file using fzf with locate.
            """
            def execute(self):
                import subprocess
                command="locate home media | fzf -e -i"
                fzf = self.fm.execute_command(command, stdout=subprocess.PIPE)
                stdout, stderr = fzf.communicate()
                if fzf.returncode == 0:
                    fzf_file = os.path.abspath(stdout.decode('utf-8').rstrip('\n'))
                    if os.path.isdir(fzf_file):
                        self.fm.cd(fzf_file)
                    else:
                        self.fm.select_file(fzf_file)


        class fzf_rga_documents_search(Command):
            """
            :fzf_rga_search_documents
            Search in PDFs, E-Books and Office documents in current directory.
            Usage: fzf_rga_search_documents <search string>
            """
            def execute(self):
                if self.arg(1):
                    search_string = self.rest(1)
                else:
                    self.fm.notify("Usage: fzf_rga_search_documents <search string>", bad=True)
                    return

                import subprocess
                import os.path
                from ranger.container.file import File
                command="rga '%s' . --rga-adapters=pandoc,poppler | fzf +m | awk -F':' '{print $1}'" % search_string
                fzf = self.fm.execute_command(command, universal_newlines=True, stdout=subprocess.PIPE)
                stdout, stderr = fzf.communicate()
                if fzf.returncode == 0:
                    fzf_file = os.path.abspath(stdout.rstrip('\n'))
                    self.fm.execute_file(File(fzf_file))


        class extract(Command):
            """:extract [dirname]
            Extract selected archives, overwriting without prompting.
            """
            def execute(self):
                from ranger.core.loader import CommandLoader

                cwd = self.fm.thisdir
                files = cwd.get_selection()

                if not files:
                    return

                def refresh(_):
                    _cwd = self.fm.get_directory(cwd.path)
                    _cwd.load_content()

                dirname = " ".join(self.line.strip().split()[1:])
                self.fm.copy_buffer.clear()
                self.fm.cut_buffer = False

                for file in files:
                    descr = "Extracting: " + os.path.basename(file.path)
                    path = file.path
                    lp = path.lower()

                    if lp.endswith('.zip'):
                        command = ['unzip', '-o', path]
                        if dirname:
                            os.makedirs(dirname, exist_ok=True)
                            command += ['-d', dirname]
                    elif any(lp.endswith(e) for e in ['.tar.gz', '.tgz', '.tar.bz2', '.tbz2', '.tar.xz', '.txz', '.tar.zst', '.tar']):
                        command = ['tar', '-xf', path]
                        if dirname:
                            os.makedirs(dirname, exist_ok=True)
                            command += ['-C', dirname]
                    elif lp.endswith('.7z'):
                        command = ['7z', 'x', path]
                        if dirname:
                            command += ['-o' + dirname]
                    elif lp.endswith('.rar'):
                        command = ['unrar', 'x', '-o+', path]
                        if dirname:
                            command += [dirname + '/']
                    else:
                        command = ['7z', 'x', path]
                        if dirname:
                            command += ['-o' + dirname]

                    obj = CommandLoader(args=command, descr=descr, read=True)
                    obj.signal_bind('after', refresh)
                    self.fm.loader.add(obj)
      '';
    };
}
