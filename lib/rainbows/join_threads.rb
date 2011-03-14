# -*- encoding: binary -*-
# :enddoc:
# This module only gets loaded on shutdown
module Rainbows::JoinThreads

  # blocking acceptor threads must be forced to run
  def self.acceptors(threads)
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
