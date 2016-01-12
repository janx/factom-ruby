$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "factom-ruby/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "factom-ruby"
  s.version     = Factom::VERSION
  s.authors     = ["Jan Xie"]
  s.email       = ["jan.h.xie@gmail.com"]
  s.homepage    = "https://github.com/janx/factom-ruby"
  s.summary     = "Ruby client consumes Factom (factom.org) API."
  s.description = "Ruby client consumes Factom (factom.org) API."
  s.license     = 'MIT'

  s.files = Dir["{lib}/**/*"] + ["LICENSE", "README.md"]

  s.add_runtime_dependency('bitcoin-ruby', ['>= 0.0.7'])
  s.add_runtime_dependency('rbnacl-libsodium', ['>= 1.0.8'])
  s.add_runtime_dependency('rbnacl', ['>= 3.3.0'])
  s.add_runtime_dependency('rest-client', ['~> 1.8.0'])
end
