# Configure SystemD units for Clone Army management
#
# This class creates a `puppet-clone-army@.service` template unit that can be
# used to start and stop individual clones by name along with a
# `puppet-clone-army.target` unit that can be used to start and stop all
# clones.
class clone_army::service {
  exec { 'clone_army systemctl reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  case fact('os.family') {
    'RedHat': {
      if fact('os.selinux.enforced') {
        # The selinux-policy-targeted package for RedHat and Fedora blocks
        # systemd-nspawn from registering running containers when launched
        # by a service unit. This can be corrected by applying some
        # configuration from the container-selinux package.
        #
        # See: https://bugzilla.redhat.com/show_bug.cgi?id=1391118
        # See: https://bugzilla.redhat.com/show_bug.cgi?id=1760146
        ensure_packages(['container-selinux'])

        file { '/usr/bin/systemd-nspawn':
          seltype => 'container_runtime_exec_t',
          require => Package['container-selinux'],
        }

        selboolean { 'container_manage_cgroup':
          persistent => true,
          value      => 'on',
          require    => Package['container-selinux'],
        }

        $_selinux_deps = [File['/usr/bin/systemd-nspawn'],
                          Selboolean['container_manage_cgroup']]
      } else {
        $_selinux_deps = []
      }
    }
    default: {
      $_selinux_deps = []
    }
  }

  file { '/etc/systemd/system/puppet-clone-army.target':
    ensure  => 'file',
    mode    => '0644',
    content => @("EOF"/L),
      [Unit]
      Description=Puppet Clone Army Containers
      PartOf=machines.target
      Before=machines.target

      [Install]
      WantedBy=machines.target
      | EOF
    notify  => Exec['clone_army systemctl reload'],
  }

  # Basically /usr/lib/systemd/system/systemd-nspawn@.service
  # but without private networking and with automagic dependencies
  # on filesystem mounts.
  file { '/etc/systemd/system/puppet-clone-army@.service':
    ensure  => 'file',
    mode    => '0644',
    content => @("EOF"/L),
      [Unit]
      Description=Puppet Agent Clone Army %I
      Documentation=man:systemd-nspawn(1)
      PartOf=puppet-clone-army.target
      Before=puppet-clone-army.target
      RequiresMountsFor=/var/lib/machines/%I

      [Service]
      ExecStart=/usr/bin/systemd-nspawn \
        --quiet \
        --keep-unit \
        --boot \
        --link-journal=try-guest \
        --machine=%I
      KillMode=mixed
      Type=notify
      RestartForceExitStatus=133
      SuccessExitStatus=133
      Slice=machine.slice
      Delegate=yes

      [Install]
      WantedBy=puppet-clone-army.target
      | EOF
    require => $_selinux_deps,
    notify  => Exec['clone_army systemctl reload'],
  }
}
