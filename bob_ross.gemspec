require_relative "lib/bob_ross/version"

Gem::Specification.new do |s|
  s.name        = "bob_ross"
  s.version     = 1
  s.authors     = ["Jon Bracy"]
  s.email       = ["jonbracy@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{}
  s.description = %q{}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # Developoment 
  s.add_development_dependency 'rack'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'activesupport'
  s.add_development_dependency 'standardstorage'
  s.add_development_dependency 'ruby-vips'
  s.add_development_dependency 'byebug'
  
  # Runtime
  s.add_runtime_dependency 'sqlite3'
  s.add_runtime_dependency 'terrapin'
  s.add_runtime_dependency 'mini_mime'
end
