# Puppet Clone Army

This module configures a Linux node running SystemD to host a fleet of
`puppet-agent` clones running inside containers. This sort of clone
deployment is useful for applying load to Puppet infrastructure servers
during testing and development.

This module currently only supports PE. Support for Open Source Puppet
may be added in a future release.

The clones run inside `systemd-nspawn` containers that use OverlayFS to
share a common `puppet-agent` install with container-local modifications.
This containerization strategy allows experimental patches to be applied to
the fleet as a whole, or to individual agents by modifying files on the host
filesystem. The use of SystemD containers also allows both the `puppet`
and `pxp-agent` services to run, and run "as root" with full functionality.

Currently, RedHat 7 is the only supported operating system for the clones.
This is expected to change as the module gains support for using `debootstrap`
and `zypper` to create base images from which the agents are cloned.


## Setup

Although not required, you may want to configure your Puppet Server with
a liberal autosigning policy:

```
# cat /etc/puppetlabs/puppet/autosign.conf
*
```

This is insecure, but can save time in a development environment by eliminating
the need to approve certificates created by the clones.


## Usage

To use the module, classify an agent node with the `clone_army` class.

`bolt apply` may also be used and requires a value to be set for the `master`
parameter of the `clone_army` class:

```
bolt apply -e 'class {"clone_army": master => "<certname of your master>"}'
```

The `num_clones` parameter may be used to specify the number of clones to
create on the agent. By default, the module will take the total RAM, subtract
an allotment for the host `puppet-agent` and OS, and then divide the remainder
by 150 MB to determine the number of clones to create.

### Interacting with Clones

Clones run under `systemd-nspawn` and can be started and stopped using the
`puppet-clone-army@<clone name>` service unit. `machinectl list` will list
the name of provisioned clones and `machinectl login` can be used to log
into a shell on a clone. The password for the `root` user is set to `puppetlabs`
and typing `Ctrl-]` three times will close the shell spawned by `machinectl login`.

The module provisions a base OS image under `/var/lib/puppet-clone-army/<base name>`
and then creates a OverlayFS mount for each clone under `/var/lib/machines/<clone name>`
that consists of the base image as a lower layer followed by `/var/lib/puppet-clone-army/<clone name>-overlay`
as an upper layer. Edits to the base image will affect the entire fleet of
clones while edits to `<clone name>-overlay` will affect only one specific clone.

## Notes

This module is based on some prior art:

  - The [`puppetlabs/clamps`][clamps] module, which creates a similar setup, but
    with user accounts and cron instead of containers and running services.

  - Julia Evans' amazing blog posts: https://jvns.ca/blog/2019/11/18/how-containers-work--overlayfs/

[clamps]: https://github.com/puppetlabs/clamps
