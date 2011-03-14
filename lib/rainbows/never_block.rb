# -*- encoding: binary -*-

# {NeverBlock}[www.espace.com.eg/neverblock/] library that combines
# the EventMachine library with Ruby Fibers.  This includes use of
# Thread-based Fibers under Ruby 1.8.  It currently does NOT support
# a streaming "rack.input" but is compatible with everything else
# EventMachine supports.
#
# In your Rainbows! config block, you may specify a Fiber pool size
# to limit your application concurrency (without using Rainbows::AppPool)
#
#   Rainbows! do
#     use :NeverBlock, :pool_size => 50
#     worker_connections 100
#   end
#
module Rainbows::NeverBlock

  # :stopdoc:
  DEFAULTS = {
    :pool_size => 20, # same default size used by NB
    :backend => :EventMachine, # NeverBlock doesn't support Rev yet
  }

  # same pool size NB core itself uses
  def self.setup # :nodoc:
    o = Rainbows::O
    DEFAULTS.each { |k,v| o[k] ||= v }
    Integer === o[:pool_size] && o[:pool_size] > 0 or
      raise ArgumentError, "pool_size must a be an Integer > 0"
    mod = Rainbows.const_get(o[:backend])
    require "never_block" # require EM first since we need a higher version
  end

  def self.extended(klass)
    klass.extend(Rainbows.const_get(Rainbows::O[:backend])) # EventMachine
    klass.extend(Rainbows::NeverBlock::Core)
  end
  # :startdoc:
end
# :enddoc:
require 'rainbows/never_block/core'
