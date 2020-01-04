class clone_army::service {
  # Basically /usr/lib/systemd/system/systemd-nspawn@.service
  # but without private networking.
  file { '/etc/systemd/system/puppet-clone-army@.service':
    ensure  => 'file',
    mode    => '0644',
    content => @("EOF"/L),
      [Unit]
      Description=Puppet Agent Clone Army %I
      Documentation=man:systemd-nspawn(1)
      PartOf=machines.target
      Before=machines.target

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
      WantedBy=machines.target
      | EOF
  }

  exec { 'clone_army systemctl reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    subscribe   => File['/etc/systemd/system/puppet-clone-army@.service'],
  }
}
