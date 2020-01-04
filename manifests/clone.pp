define clone_army::clone (
  Type[Clone_Army::Base_image] $base,
  Enum['running', 'stopped'] $state = 'running',
) {
  $_vardir = $base['vardir']
  # NOTE: Should be able to use a resource reference here instead of getparam
  $_base = join([$_vardir, getparam($base, 'title')], '/')
  $_upperdir = join([$_vardir, "${title}-overlay"], '/')
  $_workdir = join([$_vardir, "${title}-workdir"], '/')
  $_mountpoint = join(['/var/lib/machines', $title], '/')

  file {[$_upperdir, $_workdir, $_mountpoint]:
    ensure => directory,
  }

  file { "$_upperdir/etc":
    ensure => directory,
  }

  file { "${_upperdir}/etc/hostname":
    ensure  => file,
    content => @("EOF"/L),
      ${title}.${trusted['certname']}
      | EOF
  }

  file { "/etc/systemd/system/var-lib-machines-${title}.mount":
    content => @("EOF"/L),
      [Unit]
      PartOf=puppet-clone-army@${title}.service
      Before=puppet-clone-army@${title}.service

      [Mount]
      What=overlay
      Where=${_mountpoint}
      Type=overlay
      Options=lowerdir=${_base},upperdir=${_upperdir},workdir=${_workdir}

      [Install]
      RequiredBy=puppet-clone-army@${title}.service
      | EOF
    notify => Exec['clone_army systemctl reload'],
  }

  service { "var-lib-machines-${title}.mount":
    enable  => true,
    require => [File["/etc/systemd/system/var-lib-machines-${title}.mount"],
                Exec['clone_army systemctl reload']],
  }

  service {"puppet-clone-army@${title}":
    ensure  => $state,
    require => [Service["var-lib-machines-${title}.mount"],
                Exec['clone_army systemctl reload']],
  }
}
