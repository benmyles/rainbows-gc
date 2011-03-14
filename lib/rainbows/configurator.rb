# -*- encoding: binary -*-

# This module adds \Rainbows! to the
# {Unicorn::Configurator}[http://unicorn.bogomips.org/Unicorn/Configurator.html]
module Rainbows::Configurator

  # configures \Rainbows! with a given concurrency model to +use+ and
  # a +worker_connections+ upper-bound.  This method may be called
  # inside a Unicorn/\Rainbows! configuration file:
  #
  #   Rainbows! do
  #     use :ThreadSpawn # concurrency model to use
  #     worker_connections 400
  #     keepalive_timeout 0 # zero disables keepalives entirely
  #     client_max_body_size 5*1024*1024 # 5 megabytes
  #     keepalive_requests 666 # default:100
  #   end
  #
  #   # the rest of the Unicorn configuration
  #   worker_processes 8
  #
  # See the documentation for the respective Revactor, ThreadSpawn,
  # and ThreadPool classes for descriptions and recommendations for
  # each of them.  The total number of clients we're able to serve is
  # +worker_processes+ * +worker_connections+, so in the above example
  # we can serve 8 * 400 = 3200 clients concurrently.
  #
  # The default is +keepalive_timeout+ is 5 seconds, which should be
  # enough under most conditions for browsers to render the page and
  # start retrieving extra elements for.  Increasing this beyond 5
  # seconds is not recommended.  Zero disables keepalive entirely
  # (but pipelining fully-formed requests is still works).
  #
  # The default +client_max_body_size+ is 1 megabyte (1024 * 1024 bytes),
  # setting this to +nil+ will disable body size checks and allow any
  # size to be specified.
  #
  # The default +keepalive_requests+ is 100, meaning a client may
  # complete 100 keepalive requests after the initial request before
  # \Rainbows! forces a disconnect.  Lowering this can improve
  # load-balancing characteristics as it forces HTTP/1.1 clients to
  # reconnect after the specified number of requests, hopefully to a
  # less busy host or worker process.  This may also be used to mitigate
  # denial-of-service attacks that use HTTP pipelining.
  def Rainbows!(&block)
    block_given? or raise ArgumentError, "Rainbows! requires a block"
    Rainbows::HttpServer.setup(block)
  end
end

# :enddoc:
# inject the Rainbows! method into Unicorn::Configurator
Unicorn::Configurator.__send__(:include, Rainbows::Configurator)
