# -*- encoding: binary -*-
# :enddoc:
require 'raindrops'
require 'rainbows/epoll'

# Edge-triggered epoll concurrency model with blocking accept() in
# a (hopefully) native thread.  This is recommended over Epoll for
# Ruby 1.9 users as it can workaround accept()-scalability issues
# on multicore machines.
module Rainbows::XEpoll
  include Rainbows::Base
  autoload :Client, 'rainbows/xepoll/client'

  def init_worker_process(worker)
    super
    Rainbows::Epoll.const_set :EP, SleepyPenguin::Epoll.new
    Rainbows::Client.__send__ :include, Client
  end

  def worker_loop(worker) # :nodoc:
    init_worker_process(worker)
    Client.run
  end
end
