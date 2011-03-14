# -*- encoding: binary -*-
# :enddoc:
class Rainbows::CoolioThreadPool::Watcher < Coolio::TimerWatcher
  def initialize(threads)
    @threads = threads
    super(Rainbows.server.timeout, true)
  end

  def on_timer
    @threads.each { |t| t.join(0) and Rainbows.quit! }
  end
end
