#!/usr/bin/env ruby

# Gloms all the tests into one easy-to-run package.

require 'test/unit'
$: << '../lib'

# These next two are for eclipse, as it refuses to run in this directory
$: << './tests'
$: << './lib'

require 'kuiobject_tests'
require 'xml_test.rb'
require 'options_tests.rb'
require 'kuimission_tests.rb'
require 'adapter_tests.rb'
require 'search_tests.rb'