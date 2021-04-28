require_relative 'lib/scalingo_backups_manager/version'

Gem::Specification.new do |spec|
  spec.name          = "scalingo_backups_manager"
  spec.version       = ScalingoBackupsManager::VERSION
  spec.authors       = ["Kevin Clercin"]
  spec.email         = ["kevin@9troisquarts.com"]

  spec.summary       = %q{Gem allowing to download backups from scalingo}
  spec.homepage      = "https://github.com/9troisquarts/scalingo_backups_manager"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/9troisquarts/scalingo_backups_manager"
  spec.metadata["changelog_uri"] = "https://github.com/9troisquarts/scalingo_backups_manager/CHANGELOG.md"

  spec.add_dependency "thor", '~> 1.1'
  spec.add_dependency 'httparty', "~> 0.18"
  spec.add_dependency 'scalingo', '~> 3.0'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.executables   << "scalingo_backups_manager"
  spec.require_paths = ["lib"]
end
