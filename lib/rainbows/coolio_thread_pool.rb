# -*- encoding: binary -*-

# A combination of the Coolio and ThreadPool models.  This allows Ruby
# Thread-based concurrency for application processing.  It DOES NOT
# expose a streamable "rack.input" for upload processing within the
# app.  DevFdResponse should be used with this class to proxy
# asynchronous responses.  All network I/O between the client and
# server are handled by the main thread and outside of the core
# application dispatch.
#
# Unlike ThreadPool, Cool.io makes this model highly suitable for
# slow clients and applications with medium-to-slow response times
# (I/O bound), but less suitable for sleepy applications.
#
# This concurrency model is designed for Ruby 1.9, and Ruby 1.8
# users are NOT advised to use this due to high CPU usage.
module Rainbows::CoolioThreadPool
  # :stopdoc:
  autoload :Client, 'rainbows/coolio_thread_pool/client'
  DEFAULTS = {
    :pool_size => 20, # same default size as ThreadPool (w/o Coolio)
  }
  #:startdoc:

  def self.setup # :nodoc:
    o = Rainbows::O
    DEFAULTS.each { |k,v| o[k] ||= v }
    Integer === o[:pool_size] && o[:pool_size] > 0 or
      raise ArgumentError, "pool_size must a be an Integer > 0"
  end
  include Rainbows::Coolio::Core

  def init_worker_threads(master, queue) # :nodoc:
    Rainbows::O[:pool_size].times.map do
      Thread.new do
        begin
          client = queue.pop
          master << [ client, client.app_response ]
        rescue => e
          Rainbows::Error.listen_loop(e)
        end while true
      end
    end
  end

  def init_worker_process(worker) # :nodoc:
    super
    cloop = Coolio::Loop.default
    master = Rainbows::Coolio::Master.new(Queue.new).attach(cloop)
    queue = Client.const_set(:QUEUE, Queue.new)
    threads = init_worker_threads(master, queue)
    Watcher.new(threads).attach(cloop)
    logger.info "CoolioThreadPool pool_size=#{Rainbows::O[:pool_size]}"
  end
end
# :enddoc:
require 'rainbows/coolio_thread_pool/watcher'
