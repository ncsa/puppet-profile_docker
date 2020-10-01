# @summary Docker, Docker-compose, and Firewall
#
# Install Docker and Docker-compose.
#
# Depends on:
#   - puppetlabs/docker
#   - puppet/python
#
# @example
#   include profile_docker
class profile_docker {

  include ::docker
  include ::python

}
