class clone_army::service {
  exec { 'clone_army systemctl reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
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
      |EOF
    notify => Exec['clone_army systemctl reload'],
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
      |EOF
    notify => Exec['clone_army systemctl reload'],
  }
}
