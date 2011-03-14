# -*- encoding: binary -*-
Rainbows.const_set(:Rev, Rainbows::Coolio)
# Coolio is the new version of this, use that instead.
#
# Implements a basic single-threaded event model with
# {Rev}[http://rev.rubyforge.org/].  It is capable of handling
# thousands of simultaneous client connections, but with only a
# single-threaded app dispatch.  It is suited for slow clients and
# fast applications (applications that do not have slow network
# dependencies) or applications that use DevFdResponse for deferrable
# response bodies.  It does not require your Rack application to be
# thread-safe, reentrancy is only required for the DevFdResponse body
# generator.
#
# Compatibility: Whatever \Rev itself supports, currently Ruby
# 1.8/1.9.
#
# This model does not implement as streaming "rack.input" which
# allows the Rack application to process data as it arrives.  This
# means "rack.input" will be fully buffered in memory or to a
# temporary file before the application is entered.
module Rainbows::Rev; end
