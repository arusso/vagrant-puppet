node 'pm.lan' {
  include git
  include eu::repo::epel

  if $::virtual =~ /virtualbox/ {
    # We're running in vagrant, which means we do some weirdness
    $modulepath = [ '/tmp/vagrant-puppet/modules-0',
                    '/tmp/vagrant-puppet/modules-1',
                    '/tmp/vagrant-puppet/modules-2' ]

    file { '/etc/puppet/manifests':
      ensure => link,
      target => '/bs/manifests',
      force  => true,
    }
    file { '/etc/puppet/autosign.conf':
      ensure  => file,
      mode    => '0444',
      content => "*.lan",
    }
    exec { 'disable-selinux':
      command => '/usr/sbin/setenforce 0 && touch /tmp/selinux_permissive',
      creates => '/tmp/selinux_permissive',
      before  => Class['puppet']
    }
    exec { 'restart-firewall':
      command     => '/sbin/service iptables restart',
      refreshonly => true,
      subscribe   => Concat['/etc/sysconfig/iptables'],
    }
  } else {
    $modulepath = [ '/var/lib/puppet/env/$environment/modules',
                    '/var/lib/puppet/env/production/modules',
                    '/opt/share/puppet/modules',
                    '/etc/puppet/modules' ]
  }



  class { 'puppet':
    master        => true,
    modulepath    => join($modulepath,':'),
    manifest      => '/etc/puppet/manifests/site.pp',
    reports       => [ 'tagmail', 'rrdgraph', 'store' ],
    sendmail      => '/usr/sbin/sendmail',
    dns_alt_names => [ 'pm.lan', 'pm', 'puppet.lan', 'puppet' ],
    reportfrom    => 'puppet@pm.lan',
    require       => Class['eu::repo::epel'],
  }

  iptables::rule { 'block-smtp-outbound':
    comment          => 'block smtp outbound',
    chain            => 'OUTPUT',
    protocol         => 'tcp',
    destination_port => '25',
    action           => 'REJECT',
  }
  iptables::rule { 'allow-ssh-ender':
    comment            => 'allow ssh from ender.berkeley.edu',
    chain              => 'INPUT',
    protocol           => 'tcp',
    priority           => '400',
    source             => [ '169.229.240.190/25', '169.229.216.0/24' ],
    state              => 'NEW',
    destination_port   => [ '22', '443','80'],
  }
  iptables::rule { 'allow-rel-est-traffic':
    comment            => 'allow related/established traffic',
    chain              => 'INPUT',
    state              => 'RELATED,ESTABLISHED',
    priority           => '100',
  }
  iptables::rule { 'allow-ssh-all':
    comment          => 'allow ssh from world',
    destination_port => [ '22' ],
    protocol         => 'tcp',
    priority         => '110',
  }
  iptables::rule { 'allow-icmp-all':
    comment  => 'allow icmp from world',
    protocol => 'icmp',
    action   => 'accept',
    priority => '101',
  }
  iptables::rule { 'allow-puppetmaster':
    comment            => 'allow puppet agents to connect',
    action             => 'accept',
    destination_port   => '8140',
    protocol           => 'tcp',
    priority           => '100',
  }
  iptables::rule { 'allow-loopback':
    comment            => 'allow loopback',
    incoming_interface => 'lo',
    action             => 'accept',
    priority           => '100',
  }
  iptables::rule { 'input-deny-all':
    comment     => 'global deny',
    chain       => 'INPUT',
    priority    => '999',
    action      => 'REJECT',
    reject_with => 'icmp-host-prohibited',
  }
  iptables::rule { 'forward-deny-all':
    comment     => 'global deny',
    chain       => 'FORWARD',
    priority    => '999',
    action      => 'REJECT',
    reject_with => 'icmp-host-prohibited',
  }
}