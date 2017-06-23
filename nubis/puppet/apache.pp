# Define how apache should be installed and configured.
# This uses the puppetlabs-apache puppet module [0].
#
# [0] https://github.com/puppetlabs/puppetlabs-apache
#

$vhost_name = 'dpaste'
$install_root = '/var/www/dpaste'
$wsgi_path = '/var/www/dpaste/wsgi.py'
$static_root = '/var/www/dpaste/dpaste/static/'
$port = 80

include nubis_discovery

nubis::discovery::service { 'dpaste':
  tags     => [ 'apache','backend' ],
  port     => $port,
  check    => "/usr/bin/curl -If http://localhost:${port}",
  interval => '30s',
}

class {
    'apache':
        default_mods        => true,
        default_vhost       => false,
        default_confd_files => false;
    'apache::mod::wsgi':
        wsgi_socket_prefix => '/var/run/wsgi';
    'apache::mod::remoteip':
        proxy_ips => [ '127.0.0.1', '10.0.0.0/8' ];
}

apache::vhost { $::vhost_name:
    port                        => $port,
    default_vhost               => true,
    docroot                     => $::install_root,
    docroot_owner               => 'ubuntu',
    docroot_group               => 'ubuntu',
    block                       => ['scm'],
    setenvif                    => 'X_FORWARDED_PROTO https HTTPS=on',
    access_log_format           => '%a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"',
    aliases                     => [
        {
            alias => '/static',
            path  => $::static_root
        }
    ],
    wsgi_application_group      => '%{GLOBAL}',
    wsgi_daemon_process         => 'wsgi',
    wsgi_daemon_process_options => {
        processes    => '2',
        threads      => '15',
        display-name => '%{GROUP}',
    },
    wsgi_import_script          => $::wsgi_path,
    wsgi_import_script_options  => {
      process-group     => 'wsgi',
      application-group => '%{GLOBAL}'
    },
    wsgi_process_group          => 'wsgi',
    wsgi_script_aliases         => { '/' => $::wsgi_path },

    headers            => [
      "set X-Nubis-Version ${project_version}",
      "set X-Nubis-Project ${project_name}",
      "set X-Nubis-Build   ${packer_build_name}",
      "set X-Content-Type-Options 'nosniff'",
      "set X-Frame-Options 'DENY'",
      "set X-XSS-Protection '1; mode=block'",
      "set Referrer-Policy 'strict-origin-when-cross-origin'",
      "set Strict-Transport-Security 'max-age=31536000'",
      "set Content-Security-Policy \"default-src 'none'; frame-ancestors 'none'; connect-src 'self'; font-src 'self'; img-src 'self'; script-src 'self' 'unsafe-inline' https://ajax.googleapis.com; style-src 'self' 'unsafe-inline'\"",
],    

    rewrites                    => [
    {
        comment      => 'HTTPS redirect',
        rewrite_cond => ['%{HTTP:X-Forwarded-Proto} =http'],
        rewrite_rule => ['. https://%{HTTP:Host}%{REQUEST_URI} [L,R=permanent]'],
    }
]
}

