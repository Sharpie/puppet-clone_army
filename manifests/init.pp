# Configure a node to host a Puppet Clone Army
#
# This class configures a node with a RedHat 7 base image, a number of clones,
# and SystemD units that can be used to control the clones.
#
# @param master Hostname of the Puppet Master clones should be configured
#   to connect with.
#
# @param num_clones Number of clones to run on this node. Defaults to a
#  number computed by taking total available RAM, subtracting 512 MB for
#  the OS, 150 MB for the host puppet agent services and then dividing the
#  remainder by 150 MB.
class clone_army (
  String $master = pick($server_facts['servername'], 'puppet'),
  Optional[Integer] $num_clones = undef,
) {
  contain clone_army::service

  if $num_clones =~ NotUndef {
    $_num_clones = $num_clones
  } else {
    # Installed memory, minus 512 MB for the system and 150 for the
    # puppet-agent managing the system.
    $freeboard = fact('memory.system.total_bytes') - 536870900 - 157286400

    # Each puppet-agent install will consume ~150 MB for the puppet and
    # pxp-agent services.
    #
    # Assumes no other significant services are running.
    $_num_clones = $freeboard / 157286400
  }

  # TODO: Extend to match the OS of the master where possible.
  Clone_army::Base_image {'el-7':
    master => $master
  }

  Integer[1, $_num_clones].each |$i| {
    Clone_army::Clone {"clone${i}":
      base    => Clone_army::Base_image['el-7'],
      require => [Clone_army::Base_image['el-7']],
    }
  }
}
