#!/usr/bin/env ruby

# This script is designed to set up the credits.yml file

require 'yaml'

def main
  root = []
  
  devs = []
  root << ["Development",devs]
  #devs = (root["Development"] = [])
  devs << ['Created By', 'Roger Ostrander']
  devs << ['Snippets From', 'Why the Lucky Stiff']
  devs << ['','AI for game programmers (TODO: Get full cite)']
  # TODO: Put text of LGPL somewhere for this
  devs << ['rubyscript2exe.rb courtesy', 'Erik Veenstra']
  devs << ['','http://www.erikveen.dds.nl/rubyscript2exe/index.html']
  
  notmine = []
  root << ["Other Art", notmine]
  # Of the form filename, source, author, license
  notmine << ['freesansbold.ttf','Courtesy the Rubygame Distribution',nil, nil]
  notmine << ['kuiper.png', 
    'http://hubblesite.org/newscenter/archive/releases/2000/06/image/a/',
    'NASA, The Hubble Heritage Team (AURA/STScI), ESA',
    'Public Domain']

  thanks = []
  root << ["Thanks To",thanks]
  thanks << "The Rubygame Library"
  thanks << "ruby-talk"
  thanks << "Trac"
  thanks << "Git"
    
  puts root.to_yaml
end

if $0 == __FILE__
  main()
end