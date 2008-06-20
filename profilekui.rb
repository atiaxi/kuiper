#!/usr/bin/env ruby

$: << 'lib'
require 'ruby-prof'
require 'setup'

# Because this is wrapped by Gems, the usual standby of:
# if $0 == __file ... end
# doesn't work.  However, because both the script Gems wraps this with and
# this script have the same name, we can check for that.
RubyProf.start
start_kuiper
result = RubyProf.stop

printer = RubyProf::CallTreePrinter.new(result)
printer.print(STDOUT, 0)

