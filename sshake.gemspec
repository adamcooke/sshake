# frozen_string_literal: true

require File.expand_path('lib/sshake/version', __dir__)

Gem::Specification.new do |s|
  s.name          = 'sshake'
  s.description   = 'A wrapper for net/ssh to make running commands more fun'
  s.summary       = s.description
  s.homepage      = 'https://github.com/adamcooke/sshake'
  s.version       = SSHake::VERSION
  s.files         = Dir.glob('{lib}/**/*')
  s.require_paths = ['lib']
  s.authors       = ['Adam Cooke']
  s.email         = ['me@adamcooke.io']
  s.licenses      = ['MIT']
  s.add_dependency 'net-sftp', '>= 2'
  s.add_dependency 'net-ssh', '>= 2'
end
