#!/usr/bin/env ruby

require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rubygems'

require 'lib/utility'

$STRING_KUI_VERSION = $KUIPER_VERSION.join(".")# Our version number 
                                               # is [major,minor,bug]
gem_spec = Gem::Specification.new do |s|
  s.name     = "kuiper" # The name of our gem
  s.bindir   = "bin"    # The directory of the script to start the game
  s.version  = $STRING_KUI_VERSION
  s.author   = "Roger Ostrander" # Me
  s.email    = "denor@users.sourceforge.net" # Me again
  s.homepage = "http://llynmir.net/projects/kuiper/" # My trac, for now
  s.summary  = "Top down 2D space action/rpg hybrid" # The game!
  s.description = "Kuiper is a single player top-down 2D space RPG game, in " +
    "the spirit of Escape Velocity and Tradewars. " # Longer summary
  s.has_rdoc = true # Do we have rdoc?
  s.add_dependency('rubygame', '>=3.0.0') # This specifically refers to the
                                          # Rubygame gem - a .rpm or .deb will
                                          # not, as of right now, do the trick.
  s.executables << 'kuiper' # Scripts to install (i.e. the one to start
                            # the game)
  s.files = FileList.new do |fl| # Files to be put in the gem
    fl.include("{lib,ext,samples,doc,images,data}/**/*")
    fl.exclude(/svn/)
  end
  
  # Repeating ourselves from below
  s.rdoc_options << '--title' << 'Kuiper RDocs' <<
                    '--main' << 'bin/kuiper'

  s.require_paths = ["lib"] # From the root of the gem, dirs to include (for
                            # the sake of 'require')
  s.test_file  = 'tests/tests.rb'  # What we should run for unit-testing this
                                   # gem
end

Rake::GemPackageTask.new(gem_spec) do |pkg| 
  pkg.need_tar = true
  pkg.need_tar_gz = true
  pkg.need_tar_bz2 = true
  pkg.package_files.include([ "Rakefile", "credits.yml"])
end

Rake::TestTask.new do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/tests.rb']
  t.verbose=true
end

Rake::RDocTask.new do |rd|
  rd.main = "bin/kuiper"
  rd.title = "Kuiper RDocs"
  rd.rdoc_files.include("lib/**/*.rb")
  rd.rdoc_files.include("tests/**/*.rb")
end

# Adopted from whytheluckystiff:
# http://redhanded.hobix.com/inspect/churningRubyIntoExe.html

 RUBYSCRIPT2EXE   = ENV['RUBYSCRIPT2EXE'] || 'bin/rubyscript2exe.rb'
 RUBY_MAIN_SCRIPT = ENV['RUBYMAINSCRIPT'] || 'bin/kuiper'
 EXEC_TARGET      = File.join(RUBY_MAIN_SCRIPT.sub(/rb$/, 'exe') )

 file :executable do | t |
   puts RUBYSCRIPT2EXE
   unless File.exist?(RUBYSCRIPT2EXE)
     raise RuntimeError.new("rubyscript2exe.rb not found " +
       "pass with RUBYSCRIPT2EXE=/path/to/rubyscript2.rb")
   end
   sh %{ruby "#{RUBYSCRIPT2EXE}" #{RUBY_MAIN_SCRIPT}}
   #File.move(EXEC_TARGET, 'build')
   #puts "Created executable file build/#{EXEC_TARGET}.exe" 
   puts "Done"
 end
