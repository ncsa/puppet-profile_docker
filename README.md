# profile_docker

NCSA Common Profiles - Basic support for Docker & Docker Compose

## Dependencies
- [puppetlabs/docker] (https://forge.puppet.com/puppetlabs/docker)
- [puppet/python] (https://forge.puppet.com/puppet/python)

## Notes
- `Duplicate declaration: Firewallchain[INPUT:filter:IPv4]`
  - If used alongside
    [ncsa/profile_firewall](https://github.com/ncsa/puppet-profile_firewall),
    ensure that parameter `profile_firewall::manage_builtin_chains` is set to
    `false`.

## Reference
