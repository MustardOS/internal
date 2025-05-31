# muOS Internal

This repository holds all of the key infrastructure of MustardOS (muOS):

* `bin`: Custom binaries used for scripts
* `browse`: Symlinks for [SFTPGo](https://github.com/drakkan/sftpgo) to use for browsing
* `config`: Global configuration files
* `default`: System default files - This directory is populated by **Full Image** or **Update** generation scripts
* `device`: Device specific files - Has its own script and input files
* `extra`: The frontend files which are compiled from https://github.com/MustardOS/frontend
* `init`: Content partition filesystem which is moved on first install
* `kiosk`: Frontend and system kiosk values
* `script`: Various POSIX compliant script files which is the backbone of muOS
* `share`: Various shared resources used for internal scripts and applications
