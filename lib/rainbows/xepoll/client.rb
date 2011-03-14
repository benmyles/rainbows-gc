# -*- encoding: binary -*-
# :enddoc:

module Rainbows::XEpoll::Client
  N = Raindrops.new(1)
  Rainbows::Epoll.nr_clients = lambda { N[0] }
  include Rainbows::Epoll::Client
  MAX = Rainbows.server.worker_connections
  THRESH = MAX - 1
  EP = Rainbows::Epoll::EP
  THREADS = Rainbows::HttpServer::LISTENERS.map do |sock|
    Thread.new(sock) do |sock|
      sleep
      begin
        if io = sock.kgio_accept
          N.incr(0, 1)
          io.epoll_once
        end
        sleep while N[0] >= MAX
      rescue => e
        Rainbows::Error.listen_loop(e)
      end while Rainbows.alive
    end
  end

  def self.run
    THREADS.each { |t| t.run }
    Rainbows::Epoll.loop
    Rainbows::JoinThreads.acceptors(THREADS)
  end

  # only call this once
  def epoll_once
    @wr_queue = [] # may contain String, ResponsePipe, and StreamFile objects
    post_init
    EP.set(self, IN) # wake up the main thread
    rescue => e
      Rainbows::Error.write(self, e)
  end

  def on_close
    KATO.delete(self)
    N.decr(0, 1) == THRESH and THREADS.each { |t| t.run }
  end
end
