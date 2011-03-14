# -*- encoding: binary -*-
# :enddoc:
class Rainbows::CoolioThreadPool::Client < Rainbows::Coolio::ThreadClient
  # QUEUE constant will be set in worker_loop
  def app_dispatch
    QUEUE << self
  end
end
