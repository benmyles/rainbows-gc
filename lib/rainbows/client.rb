# -*- encoding: binary -*-
# :enddoc:
require "io/wait"

# this class is used for most synchronous concurrency models
class Rainbows::Client < Kgio::Socket
  def read_expire
    Time.now + Rainbows.keepalive_timeout
  end

  def kgio_wait_readable
    wait Rainbows.keepalive_timeout
  end

  # used for reading headers (respecting keepalive_timeout)
  def timed_read(buf)
    expire = nil
    begin
      case rv = kgio_tryread(16384, buf)
      when :wait_readable
        return if expire && expire < Time.now
        expire ||= read_expire
        kgio_wait_readable
      else
        return rv
      end
    end while true
  end

  include Rainbows::ProcessClient
end
