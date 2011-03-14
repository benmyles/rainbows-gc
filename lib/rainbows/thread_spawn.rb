# -*- encoding: binary -*-
require 'thread'

# Spawns a new thread for every client connection we accept().  This
# model is recommended for platforms like Ruby 1.8 where spawning new
# threads is inexpensive.
#
# This model should provide a high level of compatibility with all
# Ruby implementations, and most libraries and applications.
# Applications running under this model should be thread-safe
# but not necessarily reentrant.
#
# If you're connecting to external services and need to perform DNS
# lookups, consider using the "resolv-replace" library which replaces
# parts of the core Socket package with concurrent DNS lookup
# capabilities

module Rainbows::ThreadSpawn
  include Rainbows::Base
  include Rainbows::WorkerYield

  def accept_loop(klass) #:nodoc:
    lock = Mutex.new
    limit = worker_connections
    nr = 0
    LISTENERS.each do |l|
      klass.new(l) do |l|
        begin
          if lock.synchronize { nr >= limit }
            worker_yield
          elsif c = l.kgio_accept
            klass.new(c) do |c|
              begin
                lock.synchronize { nr += 1 }
                c.process_loop
              ensure
                lock.synchronize { nr -= 1 }
              end
            end
          end
        rescue => e
          Rainbows::Error.listen_loop(e)
        end while Rainbows.alive
      end
    end
    sleep 1 while Rainbows.tick || lock.synchronize { nr > 0 }
  end

  def worker_loop(worker) #:nodoc:
    init_worker_process(worker)
    accept_loop(Thread)
  end
end
