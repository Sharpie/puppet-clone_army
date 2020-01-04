# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2020-01-04
### Changed

  - The OverlayFS mounts used by clones are now controlled by SystemD
    mount units instead of Puppet mount resources. This ensures the
    filesystems are automatically mounted when clones start and
    ejected when clones are stopped, which allows for safe edits to
    the layers in the overlay.

  - Clones are no longer enforced to be in a running state.

### Added

  - A `puppet-clone-army.target` unit that can be used to start, stop,
    or restart all clones at once.

  - DNS behavior in clones is synced with the host by copying `/etc/resolv.conf`.

  - Hostnames of the clones are set to be `<clone name>.<host certname>`.

### Fixed

  - A symlink is no longer used for `/etc/hosts`.


## [0.1.0] - 2020-01-03
### Added

  - A `clone_army` profile with support for running `puppet-agent`
    clones in `systemd-nspawn` containers on RedHat 7.

[0.2.0]: https://github.com/Sharpie/puppet-clone_army/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/Sharpie/puppet-clone_army/compare/93235d9...0.1.0
