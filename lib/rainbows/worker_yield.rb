# -*- encoding: binary -*-
# :enddoc:
module Rainbows::WorkerYield

  # Sleep if we're busy (and let other threads run).  Another less busy
  # worker process may take it for us if we sleep. This is gross but
  # other options still suck because they require expensive/complicated
  # synchronization primitives for _every_ case, not just this unlikely
  # one.  Since this case is (or should be) uncommon, just busy wait
  # when we have to.  We don't use Thread.pass because it needlessly
  # spins the CPU during I/O wait, CPU cycles that can be better used by
  # other worker _processes_.
  def worker_yield
    sleep(0.01)
  end
end
