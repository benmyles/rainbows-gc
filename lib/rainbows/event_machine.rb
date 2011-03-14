# -*- encoding: binary -*-
require 'eventmachine'
EM::VERSION >= '0.12.10' or abort 'eventmachine 0.12.10 is required'

# Implements a basic single-threaded event model with
# {EventMachine}[http://rubyeventmachine.com/].  It is capable of
# handling thousands of simultaneous client connections, but with only
# a single-threaded app dispatch.  It is suited for slow clients,
# and can work with slow applications via asynchronous libraries such as
# {async_sinatra}[http://github.com/raggi/async_sinatra],
# {Cramp}[http://m.onkey.org/2010/1/7/introducing-cramp],
# and {rack-fiber_pool}[http://github.com/mperham/rack-fiber_pool].
#
# It does not require your Rack application to be thread-safe,
# reentrancy is only required for the DevFdResponse body
# generator.
#
# Compatibility: Whatever \EventMachine ~> 0.12.10 and Unicorn both
# support, currently Ruby 1.8/1.9.
#
# This model is compatible with users of "async.callback" in the Rack
# environment such as
# {async_sinatra}[http://github.com/raggi/async_sinatra].
#
# For a complete asynchronous framework,
# {Cramp}[http://m.onkey.org/2010/1/7/introducing-cramp] is fully
# supported when using this concurrency model.
#
# This model is fully-compatible with
# {rack-fiber_pool}[http://github.com/mperham/rack-fiber_pool]
# which allows each request to run inside its own \Fiber after
# all request processing is complete.
#
# Merb (and other frameworks/apps) supporting +deferred?+ execution as
# documented at http://brainspl.at/articles/2008/04/18/deferred-requests-with-merb-ebb-and-thin
# will also get the ability to conditionally defer request processing
# to a separate thread.
#
# This model does not implement as streaming "rack.input" which allows
# the Rack application to process data as it arrives.  This means
# "rack.input" will be fully buffered in memory or to a temporary file
# before the application is entered.
module Rainbows::EventMachine
  autoload :ResponsePipe, 'rainbows/event_machine/response_pipe'
  autoload :ResponseChunkPipe, 'rainbows/event_machine/response_chunk_pipe'
  autoload :TryDefer, 'rainbows/event_machine/try_defer'
  autoload :Client, 'rainbows/event_machine/client'

  include Rainbows::Base

  # runs inside each forked worker, this sits around and waits
  # for connections and doesn't die until the parent dies (or is
  # given a INT, QUIT, or TERM signal)
  def worker_loop(worker) # :nodoc:
    init_worker_process(worker)
    server = Rainbows.server
    server.app.respond_to?(:deferred?) and
      server.app = TryDefer.new(server.app)

    # enable them both, should be non-fatal if not supported
    EM.epoll
    EM.kqueue
    logger.info "#@use: epoll=#{EM.epoll?} kqueue=#{EM.kqueue?}"
    client_class = Rainbows.const_get(@use).const_get(:Client)
    max = worker_connections + LISTENERS.size
    Rainbows::EventMachine::Server.const_set(:MAX, max)
    Rainbows::EventMachine::Server.const_set(:CL, client_class)
    client_class.const_set(:APP, Rainbows.server.app)
    EM.run {
      conns = EM.instance_variable_get(:@conns) or
        raise RuntimeError, "EM @conns instance variable not accessible!"
      Rainbows::EventMachine::Server.const_set(:CUR, conns)
      EM.add_periodic_timer(1) do
        unless Rainbows.tick
          conns.each_value { |c| client_class === c and c.quit }
          EM.stop if conns.empty? && EM.reactor_running?
        end
      end
      LISTENERS.map! do |s|
        EM.watch(s, Rainbows::EventMachine::Server) do |c|
          c.notify_readable = true
        end
      end
    }
  end
end
# :enddoc:
require 'rainbows/event_machine/server'
