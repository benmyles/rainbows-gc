# -*- encoding: binary -*-
require 'revactor'
require 'fcntl'
Revactor::VERSION >= '0.1.5' or abort 'revactor 0.1.5 is required'

# Enables use of the Actor model through
# {Revactor}[http://revactor.org] under Ruby 1.9.  It spawns one
# long-lived Actor for every listen socket in the process and spawns a
# new Actor for every client connection accept()-ed.
# +worker_connections+ will limit the number of client Actors we have
# running at any one time.
#
# Applications using this model are required to be reentrant, but do
# not have to worry about race conditions unless they use threads
# internally.  \Rainbows! does not spawn threads under this model.
# Multiple instances of the same app may run in the same address space
# sequentially (but at interleaved points).  Any network dependencies
# in the application using this model should be implemented using the
# \Revactor library as well, to take advantage of the networking
# concurrency features this model provides.
module Rainbows::Revactor
  autoload :Client, 'rainbows/revactor/client'
  autoload :Proxy, 'rainbows/revactor/proxy'

  include Rainbows::Base

  # runs inside each forked worker, this sits around and waits
  # for connections and doesn't die until the parent dies (or is
  # given a INT, QUIT, or TERM signal)
  def worker_loop(worker) #:nodoc:
    Client.setup
    init_worker_process(worker)
    nr = 0
    limit = worker_connections
    actor_exit = Case[:exit, Actor, Object]

    revactorize_listeners.each do |l, close, accept|
      Actor.spawn(l, close, accept) do |l, close, accept|
        Actor.current.trap_exit = true
        l.controller = l.instance_variable_set(:@receiver, Actor.current)
        begin
          while nr >= limit
            l.disable if l.enabled?
            logger.info "busy: clients=#{nr} >= limit=#{limit}"
            Actor.receive do |f|
              f.when(close) {}
              f.when(actor_exit) { nr -= 1 }
              f.after(0.01) {} # another listener could've gotten an exit
            end
          end

          l.enable unless l.enabled?
          Actor.receive do |f|
            f.when(close) {}
            f.when(actor_exit) { nr -= 1 }
            f.when(accept) do |_, _, s|
              nr += 1
              Actor.spawn_link(s) { |c| Client.new(c).process_loop }
            end
          end
        rescue => e
          Rainbows::Error.listen_loop(e)
        end while Rainbows.alive
        Actor.receive do |f|
          f.when(close) {}
          f.when(actor_exit) { nr -= 1 }
        end while nr > 0
      end
    end

    Actor.sleep 1 while Rainbows.tick || nr > 0
    rescue Errno::EMFILE
      # ignore, let another worker process take it
  end

  def revactorize_listeners
    LISTENERS.map do |s|
      case s
      when TCPServer
        l = Revactor::TCP.listen(s, nil)
        [ l, T[:tcp_closed, Revactor::TCP::Socket],
          T[:tcp_connection, l, Revactor::TCP::Socket] ]
      when UNIXServer
        l = Revactor::UNIX.listen(s)
        [ l, T[:unix_closed, Revactor::UNIX::Socket ],
          T[:unix_connection, l, Revactor::UNIX::Socket] ]
      end
    end
  end
  # :startdoc:
end
