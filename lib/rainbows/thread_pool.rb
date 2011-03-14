# -*- encoding: binary -*-

# Implements a worker thread pool model.  This is suited for platforms
# like Ruby 1.9, where the cost of dynamically spawning a new thread
# for every new client connection is higher than with the ThreadSpawn
# model.
#
# This model should provide a high level of compatibility with all
# Ruby implementations, and most libraries and applications.
# Applications running under this model should be thread-safe
# but not necessarily reentrant.
#
# Applications using this model are required to be thread-safe.
# Threads are never spawned dynamically under this model.  If you're
# connecting to external services and need to perform DNS lookups,
# consider using the "resolv-replace" library which replaces parts of
# the core Socket package with concurrent DNS lookup capabilities.
#
# This model probably less suited for many slow clients than the
# others and thus a lower +worker_connections+ setting is recommended.

module Rainbows::ThreadPool
  include Rainbows::Base

  def worker_loop(worker) # :nodoc:
    init_worker_process(worker)
    pool = (1..worker_connections).map do
      Thread.new { LISTENERS.size == 1 ? sync_worker : async_worker }
    end

    while Rainbows.alive
      # if any worker dies, something is serious wrong, bail
      pool.each do |thr|
        Rainbows.tick or break
        thr.join(1) and Rainbows.quit!
      end
    end
    Rainbows::JoinThreads.acceptors(pool)
  end

  def sync_worker # :nodoc:
    s = LISTENERS[0]
    begin
      c = s.kgio_accept and c.process_loop
    rescue => e
      Rainbows::Error.listen_loop(e)
    end while Rainbows.alive
  end

  def async_worker # :nodoc:
    begin
      # TODO: check if select() or accept() is a problem on large
      # SMP systems under Ruby 1.9.  Hundreds of native threads
      # all working off the same socket could be a thundering herd
      # problem.  On the other hand, a thundering herd may not
      # even incur as much overhead as an extra Mutex#synchronize
      ret = select(LISTENERS) and ret[0].each do |s|
        s = s.kgio_tryaccept and s.process_loop
      end
    rescue Errno::EINTR
    rescue => e
      Rainbows::Error.listen_loop(e)
    end while Rainbows.alive
  end

  def join_threads(threads) # :nodoc:
    Rainbows.quit!
    threads.delete_if do |thr|
      Rainbows.tick
      begin
        thr.run
        thr.join(0.01)
      rescue
        true
      end
    end until threads.empty?
  end
end
