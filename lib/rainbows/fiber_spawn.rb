# -*- encoding: binary -*-
require 'rainbows/fiber'

# Simple Fiber-based concurrency model for 1.9.  This spawns a new
# Fiber for every incoming client connection and the root Fiber for
# scheduling and connection acceptance.  This exports a streaming
# "rack.input" with lightweight concurrency.  Applications are
# strongly advised to wrap all slow IO objects (sockets, pipes) using
# the Rainbows::Fiber::IO class whenever possible.
module Rainbows::FiberSpawn
  include Rainbows::Fiber::Base

  def worker_loop(worker) # :nodoc:
    init_worker_process(worker)
    Rainbows::Fiber::Base.setup(self.class, app)
    limit = worker_connections

    begin
      schedule do |l|
        break if Rainbows.cur >= limit
        io = l.kgio_tryaccept or next
        Fiber.new { process(io) }.resume
      end
    rescue => e
      Rainbows::Error.listen_loop(e)
    end while Rainbows.cur_alive
  end
end
