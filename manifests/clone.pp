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

  mount {$_mountpoint:
    ensure  => mounted,
    device  => 'overlay',
    fstype  => 'overlay',
    options => "lowerdir=${_base},upperdir=${_upperdir},workdir=${_workdir}",
    require => [File[$_upperdir], File[$_workdir], File[$_mountpoint]],
  }

  service {"puppet-clone-army@${title}":
    ensure => $state,
  }
}
