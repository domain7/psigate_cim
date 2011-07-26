# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "psigate_cim/version"

Gem::Specification.new do |s|
  s.name        = "psigate_cim"
  s.version     = PsigateCim::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Shane Davies"]
  s.email       = ["shane@domain7.com"]
  s.homepage    = "http://domain7.com"
  s.summary     = %q{Implements Psigate Account Manager gateway as an active merchant gem}
  s.description = %q{Psigate Account Manager Implementation of active merchant payment gateway}

  s.add_dependency(%q{activemerchant})

  s.rubyforge_project = "psigate_cim"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
