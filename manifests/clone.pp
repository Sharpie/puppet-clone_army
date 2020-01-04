# Configure Clone Army instance
#
# This defined type creates a `systemd-nspawn` container that hosts services
# from the `puppet-agent` package. The container consists of an overlay file
# system using the sysroot managed by a {clone_army::base} instance as the
# lower layer along with an upper layer that contains changes specific to the
# clone. The overlay is controlled by a SystemD mount unit that is configured
# to mount and unmount if the clone instance is started or stopped.
#
# Clones may be controlled using the SystemD units created by the
# {clone_army::service} class.
#
# @see clone_army::base
# @see clone_army::service
# @see https://www.freedesktop.org/software/systemd/man/systemd.mount.html
# @see https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt
# @see https://www.freedesktop.org/software/systemd/man/hostname.html
#
# @param base An instance of the `Clone_army::Base` defined type that this
#   clone will use as its base image.
define clone_army::clone (
  Type[Clone_Army::Base_image] $base,
) {
  include clone_army::service

  $_vardir = $base['vardir']
  # NOTE: Should be able to use a resource reference here instead of getparam
  $_base = join([$_vardir, getparam($base, 'title')], '/')
  $_upperdir = join([$_vardir, "${title}-overlay"], '/')
  $_workdir = join([$_vardir, "${title}-workdir"], '/')
  $_mountpoint = join(['/var/lib/machines', $title], '/')

  file {[$_upperdir, $_workdir, $_mountpoint, "${_upperdir}/etc"]:
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
    notify  => Exec['clone_army systemctl reload'],
  }

  service { "var-lib-machines-${title}.mount":
    enable  => true,
    require => [File["/etc/systemd/system/var-lib-machines-${title}.mount"],
                Exec['clone_army systemctl reload']],
  }

  service {"puppet-clone-army@${title}":
    enable  => true,
    require => [Service["var-lib-machines-${title}.mount"],
                Exec['clone_army systemctl reload']],
  }
}
