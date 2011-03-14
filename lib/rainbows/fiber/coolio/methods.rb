# -*- encoding: binary -*-
# :enddoc:
module Rainbows::Fiber::Coolio::Methods
  class Watcher < Coolio::IOWatcher
    def initialize(fio, flag)
      @f = Fiber.current
      super(fio, flag)
      attach(Coolio::Loop.default)
    end

    def on_readable
      @f.resume
    end

    alias on_writable on_readable
  end

  def close
    @w.detach if defined?(@w) && @w.attached?
    @r.detach if defined?(@r) && @r.attached?
    super
  end

  def kgio_wait_writable
    @w = Watcher.new(self, :w) unless defined?(@w)
    @w.enable unless @w.enabled?
    Fiber.yield
    @w.disable
  end

  def kgio_wait_readable
    @r = Watcher.new(self, :r) unless defined?(@r)
    @r.enable unless @r.enabled?
    Fiber.yield
    @r.disable
  end
end

[
  Rainbows::Fiber::IO,
  Rainbows::Client,
  # the next two trigger autoload, ugh, oh well...
  Rainbows::Fiber::IO::Socket,
  Rainbows::Fiber::IO::Pipe
].each do |klass|
  klass.__send__(:include, Rainbows::Fiber::Coolio::Methods)
end
