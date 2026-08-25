/* mono-mic-shim — the stable-identity launcher for the mono-mic bridge.
 *
 * WHY THIS EXISTS. macOS TCC will not grant microphone access to a bare
 * executable in /nix/store: there is no bundle for Privacy & Security to list,
 * no UI to prompt from, and the store path changes on every rebuild. A denied
 * client is not told so — CoreAudio hands it a stream of digital silence — so
 * the bridge ran for three days copying zeros into BlackHole with no error
 * anywhere. See modules/services/mono-mic.nix for the measurements.
 *
 * So the bridge is launched from inside an .app bundle, and this is that
 * bundle's main executable. Two properties matter, and both are the reason this
 * is C rather than a shell script:
 *
 *   1. IT MUST BE A MACH-O BINARY. TCC attributes a request to the process's
 *      code identity. If the bundle's main executable were a script, the
 *      identity would resolve to the interpreter (/bin/sh), not to this bundle,
 *      and the grant would attach to the shell instead.
 *
 *   2. ITS BYTES MUST NOT CHANGE WHEN THE BRIDGE CHANGES. An ad-hoc signature
 *      gives TCC a cdhash-based designated requirement, so anything that alters
 *      the bundle invalidates the grant. This file therefore contains no store
 *      path: the command to run is read at startup from a config file OUTSIDE
 *      the bundle, which home-manager rewrites freely on every rebuild. The
 *      cdhash only moves if this source or the compiler does.
 *
 * IT FORKS RATHER THAN EXEC'ING, and that is load-bearing. execv would replace
 * this image in-place, leaving the process with Python's code identity and no
 * grant. Forking keeps this binary alive as the parent, so the child inherits
 * it as its TCC "responsible process" — the same mechanism that lets a CLI tool
 * run in Terminal.app borrow Terminal's microphone grant.
 *
 * The config file is one argument per line, so no quoting or word-splitting
 * rules have to be agreed on between here and Nix.
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX_ARGS 64
#define MAX_LINE 4096

/* Relative to $HOME. Must match `commandFile` in modules/services/mono-mic.nix. */
#define COMMAND_FILE "Library/Application Support/mono-mic/command"

static volatile pid_t child = -1;

/* launchd stops a job with SIGTERM; the bridge is in the child, so pass it on
 * and let the normal waitpid path report the exit. */
static void forward_signal(int signal_number) {
    if (child > 0) {
        kill(child, signal_number);
    }
}

int main(void) {
    const char *home = getenv("HOME");
    if (home == NULL) {
        fprintf(stderr, "mono-mic-shim: HOME is unset\n");
        return 78; /* EX_CONFIG */
    }

    char path[MAX_LINE];
    if (snprintf(path, sizeof path, "%s/%s", home, COMMAND_FILE) >= (int)sizeof path) {
        fprintf(stderr, "mono-mic-shim: command path too long\n");
        return 78;
    }

    FILE *file = fopen(path, "r");
    if (file == NULL) {
        fprintf(stderr, "mono-mic-shim: cannot read %s: %s\n", path, strerror(errno));
        return 78;
    }

    char *argv[MAX_ARGS];
    int argc = 0;
    char line[MAX_LINE];
    while (argc < MAX_ARGS - 1 && fgets(line, sizeof line, file) != NULL) {
        size_t length = strlen(line);
        while (length > 0 && (line[length - 1] == '\n' || line[length - 1] == '\r')) {
            line[--length] = '\0';
        }
        if (length == 0) {
            continue;
        }
        argv[argc] = strdup(line);
        if (argv[argc] == NULL) {
            fprintf(stderr, "mono-mic-shim: out of memory\n");
            fclose(file);
            return 70; /* EX_SOFTWARE */
        }
        argc++;
    }
    fclose(file);
    argv[argc] = NULL;

    if (argc == 0) {
        fprintf(stderr, "mono-mic-shim: %s is empty\n", path);
        return 78;
    }

    signal(SIGTERM, forward_signal);
    signal(SIGINT, forward_signal);
    signal(SIGHUP, forward_signal);

    child = fork();
    if (child < 0) {
        fprintf(stderr, "mono-mic-shim: fork: %s\n", strerror(errno));
        return 70;
    }
    if (child == 0) {
        execv(argv[0], argv);
        fprintf(stderr, "mono-mic-shim: exec %s: %s\n", argv[0], strerror(errno));
        _exit(127);
    }

    int status = 0;
    while (waitpid(child, &status, 0) < 0) {
        if (errno != EINTR) {
            fprintf(stderr, "mono-mic-shim: waitpid: %s\n", strerror(errno));
            return 70;
        }
        /* A forwarded signal interrupted the wait; keep waiting for the child. */
    }
    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }
    return WEXITSTATUS(status);
}
