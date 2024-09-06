# @summary Utility class used to install LCMAPS and LCAS and configure mapping software and files. 
#
# @param gridmapdir_owner
#   The owner of /etc/grid-security/gridmapdir
#
# @param gridmapdir_group
#   The group of /etc/grid-security/gridmapdir
#
# @param gridmapdir_mode
#   The permissions on /etc/grid-security/gridmapdir
#
# @param pools
#   The Array of pool accounts.
#
# @param generate_gridmapfile
#
# @param gridmapfile_file
#
# @param generate_groupmapfile
#
# @param groupmapfile_file
#
# @param manage_lcmaps_db_file
#   If true (default) use as /etc/lcmaps/lcmaps.db the file specified with lcmaps_db_file.
#   If false, file is not managed by this class.
#
# @param lcmaps_db_file
#   The path of the lcmaps.db to copy into /etc/lcmaps/lcmaps.db. Default: puppet:///modules/storm/etc/lcmaps/lcmaps.db
#
# @param manage_gsi_authz_file
#   If true (default) use as /etc/grid-security/gsi-authz.conf the file specified with gsi_authz_file.
#   If false, file is not managed by this class.
#
# @param gsi_authz_file
#   The path of the gsi-authz.conf to copy into /etc/grid-security/gsi-authz.conf. Default: puppet:///modules/storm/etc/grid-security/gsi-authz.conf
#
# @example Example of usage
#    class { 'lcmaps':
#      pools => [{
#        'name' => 'dteam',
#        'size' => 20,
#        'base_uid' => 7100,
#        'group' => 'dteam',
#        'gid' => 7100,
#        'vo' => 'dteam',
#      }],
#      manage_lcas_ban_users_file => false,
#    }
#
class lcmaps (

  String $gridmapdir_owner,
  String $gridmapdir_group,
  String $gridmapdir_mode,

  Array[Lcmaps::PoolData] $pools,

  Boolean $generate_gridmapfile,
  String $gridmapfile_file,

  Boolean $generate_groupmapfile,
  String $groupmapfile_file,

  Boolean $manage_lcmaps_db_file,
  String $lcmaps_db_file,

  Boolean $manage_gsi_authz_file,
  String $gsi_authz_file,

) {
  $lcamps_rpms = ['lcmaps', 'lcmaps-without-gsi']
  package { $lcamps_rpms:
    ensure => latest,
  }

  $gridmapdir = '/etc/grid-security/gridmapdir'

  if !defined(File[$gridmapdir]) {
    file { $gridmapdir:
      ensure  => directory,
      owner   => $gridmapdir_owner,
      group   => $gridmapdir_group,
      mode    => $gridmapdir_mode,
      recurse => true,
    }
  }

  $pools.each | $pool | {
    # mandatories
    $pool_name = $pool['name']
    $pool_group = $pool['group']
    $pool_gid = $pool['gid']
    $pool_vo = $pool['vo']
    $pool_base_uid = $pool['base_uid']
    $pool_size = $pool['size']

    # optionals
    if ('groups' in $pool) {
      $pool_groups = $pool['groups']
    } else {
      $pool_groups = [$pool_group]
    }

    group { $pool_group:
      ensure => present,
      gid    => $pool_gid,
    }
    $pool_groups.each | $g | {
      if !defined(Group[$g]) {
        group { $g:
          ensure => present,
        }
      }
    }

    range('1', $pool_size).each | $id | {
      $id_str = sprintf('%03d', $id)
      $name = "${pool_name}${id_str}"

      user { $name:
        ensure     => present,
        uid        => $pool_base_uid + $id,
        gid        => $pool_gid,
        groups     => $pool_groups,
        comment    => "Mapped user for ${pool_vo}",
        managehome => true,
        require    => [Group[$pool_group]],
      }

      file { "${gridmapdir}/${name}":
        ensure  => file,
        require => File[$gridmapdir],
        owner   => $gridmapdir_owner,
        group   => $gridmapdir_group,
      }
    }
  }

  $gridmapfile='/etc/grid-security/grid-mapfile'
  $gridmapfile_template='lcmaps/etc/grid-security/grid-mapfile.erb'

  if $generate_gridmapfile {
    file { $gridmapfile:
      ensure  => file,
      content => template($gridmapfile_template),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }
  } else {
    file { $gridmapfile:
      ensure => file,
      source => $gridmapfile_file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
    }
  }

  $groupmapfile='/etc/grid-security/groupmapfile'
  $groupmapfile_template='lcmaps/etc/grid-security/groupmapfile.erb'

  if $generate_groupmapfile {
    file { $groupmapfile:
      ensure  => file,
      content => template($groupmapfile_template),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
    }
  } else {
    file { $groupmapfile:
      ensure => file,
      source => $groupmapfile_file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
    }
  }

  if $manage_gsi_authz_file {
    file { '/etc/grid-security/gsi-authz.conf':
      ensure => file,
      source => $gsi_authz_file,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
    }
  }

  if $manage_lcmaps_db_file {
    file { '/etc/lcmaps/lcmaps.db':
      ensure  => file,
      source  => $lcmaps_db_file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => Package[$lcamps_rpms],
    }
  }
}
