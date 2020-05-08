# @summary Docker, Docker-compose, and Firewall
#
# Install Docker and Docker-compose.
#
# Ensure chains and rules created by docker are not purged by puppet.
#
# Firewallchain adjustments based on:
# https://gist.github.com/pmoranga/9c4f194a1ac4102d4f94
# and
# https://github.com/lsst-it/puppet-baseline_cfg/blob/c9fcdf072126c3f42a0322ffef9ddfad46a05e2/manifests/firewall.pp
#
# Depends on:
#   - puppetlabs/docker
#   - puppet/python
#   - ncsa/profile_firewall
#
# @note Ensure that profile_firewall::manage_builtin_chains = false
#
# @param $purge_exempt_chains
#
# @param $purge_exceptions
#
# @param $default_chains
#   OPTIONAL - Hash of chains to use in place of
#   "profile_firewall::builtin_chains::tables".
#   Default = value from profile_firewall::builtin_chains::tables
#
# @example
#   include profile_docker
class profile_docker (
  Optional[ Hash ] $builtin_chains,
  Array            $purge_exceptions,
  Hash             $purge_exempt_chains,
) {
    include ::docker
    include ::python

    $inbuilt_chains = $builtin_chains ? {
      Undef   => lookup( 'profile_firewall::builtin_chains::tables', Hash ),
      default => $builtin_chains,
    }


    ###
    #   DEFAULT CHAINS
    ###
    # Build a hash of { "chain:table:protocol" => params }
    # where params = {}
    # params are valid puppetlabs::firewallchain parameters
    $_default_params = {}
    $_default_chains = $inbuilt_chains.reduce( {} ) |$memo, $parts| {
      $table = $parts[0]
     # notify { "TABLE... ${table}" : }
      $t_data = $parts[1]
      # notify { "${table} DATA... ${t_data}" : }
      $keys = $t_data['chains'].map() |$chain| {
        $t_data['protocols'].map() |$protocol| {
          "${chain}:${table}:${protocol}"
        }
      }.flatten()
      # notify { "KEYS: ${keys}" : }
      $memo + $keys.reduce({}) |$result, $elem| {
        $result + { $elem => $_default_params }
      }
    }
    # notify { "ALL DEFAULT CHAINS ... $_default_chains" : }


    ###
    #   PURGE EXEMPT CHAINS
    ###
    # Build a hash of { "chain:table:protocol" => params }
    # where params = { 'purge' => false }
    # params are valid puppetlabs::firewallchain parameters
    $_exempt_params = { 'purge' => false }
    $_exempt_chains = $purge_exempt_chains.reduce( {} ) |$memo, $parts| {
      $table = $parts[0]
      # notify { "TABLE... ${table}" : }
      $list_of = $parts[1]
      # notify { "${table} DATA... ${list_of}" : }
      $keys = $list_of['chains'].map() |$chain| {
        $list_of['protocols'].map() |$protocol| {
          "${chain}:${table}:${protocol}"
        }
      }.flatten()
      # notify { "KEYS: ${keys}" : }
      $memo + $keys.reduce({}) |$result, $key| {
        $result + { $key => $_exempt_params }
      }
    }
    # notify { "ALL EXEMPT CHAINS ... $_exempt_chains" : }




    ###
    #   PURGE EXCEPTIONS
    ###
    # Build a hash of { "chain:table:protocol" => params }
    # where params = { 'ignore' => <LIST-OF-IGNORE-STRING-REGEXS> }
    # params are valid puppetlabs::firewallchain parameters
    $_exception_chains = $purge_exceptions.reduce( {} ) |$new_data, $exc_data | {
      #exc_data is a hash with keys "ignores", "tables"
      $_ignore_params = { 'ignore' => $exc_data['ignores'] }
      $_tables = $exc_data['tables']
      # from here, it's the same logic as above, but using custom $_ignore_params
      $_ignore_chains = $_tables.reduce( {} ) |$memo, $parts| {
        $table = $parts[0]
        # notify { "TABLE... ${table}" : }
        $list_of = $parts[1]
        # notify { "${table} DATA... ${list_of}" : }
        $keys = $list_of['chains'].map() |$chain| {
          $list_of['protocols'].map() |$protocol| {
            "${chain}:${table}:${protocol}"
          }
        }.flatten()
        # notify { "KEYS: ${keys}" : }
        $memo + $keys.reduce({}) |$result, $key| {
          $result + { $key => $_ignore_params }
        }
      }
      $new_data + $_ignore_chains
    }
    # notify { "CHAINS WITH EXCEPTIONS ... $_exception_chains" : }

    # Merge hashes of chain names, allowing overrides to mask defaults.
    # Higher priority overrides lower priority
    # Priority order (from lowest to highest) is:
    # Defaults -> Exceptions -> Exemptions
    $_intermediate_1 = $_default_chains + $_exception_chains
    $_final_chains = $_intermediate_1 + $_exempt_chains
    notify { "FINAL CHAINS... $_final_chains" : }

    # Actually create firewallchains
    $chain_defaults = {
      purge => true,
    }
    create_resources( firewallchain, $_final_chains, $chain_defaults )
    # $_final_chains.each | $name, $params | {
    #   firewallchain {
    #     $name :
    #       * => $params,
    #     ;
    #     default :
    #         purge => true,
    #     ;
    #   }
    # }

    # SAMPLE BUILT-IN CHAINS
#    $inbuilt_chains = {
#      filter => {
#        chains => [ 'INPUT' , 'OUTPUT' , 'FORWARD' ],
#        protocols => [ 'IPv4' , 'IPv6' ],
#      },
#      nat => {
#        chains => [ 'PREROUTING' , 'POSTROUTING' , 'INPUT' , 'OUTPUT' ],
#        protocols => [ 'IPv4' , 'IPv6' ],
#      },
#      mangle => {
#        chains => [ 'INPUT' , 'OUTPUT' , 'FORWARD' , 'PREROUTING' , 'POSTROUTING' ],
#        protocols => [ 'IPv4' , 'IPv6' ],
#      },
#      raw => {
#        chains => [ 'OUTPUT' , 'PREROUTING' ],
#        protocols => [ 'IPv4' , 'IPv6' ],
#      },
#    }

    #    SAMPLE
#    $purge_exempt_chains = {
#        filter => {
#            chains => [ "DOCKER", "DOCKER-ISOLATION-STAGE-1", "DOCKER-ISOLATION-STAGE-2", "DOCKER-USER" ],
#            protocols => [ "IPv4" ],
#        },
#        nat => {
#            chains => [ "DOCKER", "DOCKER-ISOLATION-STAGE-1", "DOCKER-ISOLATION-STAGE-2", "DOCKER-USER" ],
#            protocols => [ "IPv4" ],
#        },
#    }

    #    SAMPLE
#    $purge_exceptions = [
#        {   ignores => [ "DOCKER" , "DOCKER-ISOLATION-STAGE-1" , "DOCKER-ISOLATION-STAGE-2" , "DOCKER-USER" , "docker" ],
#            tables => {
#                filter => {
#                    chains => [ "INPUT" , "OUTPUT" , "FORWARD" ],
#                    protocols => [ "IPv4" ],
#                },
#                nat => {
#                    chains => [ "INPUT" , "OUTPUT" ],
#                    protocols => [ "IPv4" ],
#                },
#            },
#        },
#        {   ignores =>  [ "DOCKER", "DOCKER-ISOLATION-STAGE-1", "DOCKER-ISOLATION-STAGE-2", "DOCKER-USER", "docker", "172.17", "172.18", "172.19" ],
#            tables => {
#                nat => {
#                    chains => [ "PREROUTING" ],
#                    protocols => [ "IPv4" ],
#                },
#            },
#        },
#    ]
}
