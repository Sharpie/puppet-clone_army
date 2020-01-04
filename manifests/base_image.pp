# Configure Clone Army base image
#
# This defined type creates a sysroot that can be used as the runtime
# environment of a `systemd-nspawn` container. These base images are
# intended to be used as the shared lower layer of overlay filesystems
# used by {clone_army::clone} instances.
#
# After creation, the sysroot is configured to share DNS settings with
# the host and a puppet agent is installed. The password for the `root`
# user is also set to `puppetlabs`.
#
# @see clone_army::clone
# @see https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html
#
# @param vardir A directory uneder which the base image and its clones
#   will be stored.
#
# @param master The hostname of the puppet master that clones of this
#   base image will connect to.
define clone_army::base_image (
  String $vardir = '/var/lib/puppet-clone-army',
  String $master = 'puppet',
) {
  # Multiple base images may share the same vardir.
  ensure_resource('file', $vardir, {ensure => directory})
  $_path = join([$vardir, $title], '/')

  # TODO: Use debootstrap for Debian machines
  # TODO: Use zypper --root for SLES machines
  exec {"create ${title} base container":
    command => @("EOS"/L),
      /usr/bin/yum  \
        --installroot=${_path} \
        --releasever=${facts['os']['release']['major']} \
        install -y \
          centos-release \
          curl \
          git \
          hostname \
          passwd \
          patch \
          systemd \
          vim \
          yum \
          yum-plugin-ovl
      |-EOS
    creates => "${_path}/etc/redhat-release",
  }

  # TODO: Add option to use puppet_agent for FOSS installs
  file {"${_path}/install-puppet.sh":
    content => @("EOF"),
      #!/bin/bash

      curl -k https://${master}:8140/packages/current/install.bash | \
        bash -s -- \
          --puppet-service-ensure stopped \
          --puppet-service-enable false

      /opt/puppetlabs/bin/puppet config delete certname

      # Should be possible to use `puppet resource service`, but for
      # some reason Puppet doesn't resolve enabled states inside
      # a systemd-nspawn container. Likely a bug.
      systemctl enable puppet
      | EOF
    mode    => '0755',
    require => Exec["create ${title} base container"],
  }

  exec {"provision puppet-agent for ${title}":
    command => @("EOS"),
      /usr/bin/systemd-nspawn \
        -D ${_path} \
        bash ./install-puppet.sh
      |-EOS
    creates => "${_path}/opt/puppetlabs/puppet/VERSION",
    require => File["${_path}/install-puppet.sh"],
  }

  file {"${_path}/etc/hosts":
    ensure  => file,
    source  => '/etc/hosts',
    require => Exec["create ${title} base container"],
  }

  file {"${_path}/etc/resolv.conf":
    ensure  => file,
    source  => '/etc/resolv.conf',
    require => Exec["create ${title} base container"],
  }

  # Remove securetty to prevent PAM from blocking `machinectl login`
  file {"${_path}/etc/securetty":
    ensure  => absent,
    require => Exec["create ${title} base container"],
  }

  # Set well-known password for root login via `machinectl login`
  #
  # NOTE: Ideally this would be set using pw_hash from stdlib. But, pw_hash()
  #       on macOS cannot generate Linux hashes, which means `bolt apply`
  #       does not work. So, we just use a canned hash value.
  augeas {'clone_army base container root password':
    context => "/files/${_path}/etc/shadow",
    incl    => "${_path}/etc/shadow",
    lens    => 'Shadow.lns',
    changes => [
      # "puppetlabs"
      'set root/password "$5$NaCl$zgOC59aimZi/HwooGdPEyYgn144lBH1dbOxtKjyjIQ3"',
    ],
    require => Exec["create ${title} base container"],
  }
}
