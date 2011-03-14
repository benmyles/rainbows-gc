# -*- encoding: binary -*-
# :enddoc:
require 'thread'
class Rainbows::SyncClose
  def initialize(body)
    @body = body
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @mutex.synchronize do
      yield self
      @cv.wait(@mutex)
    end
  end

  def respond_to?(m)
    @body.respond_to?(m)
  end

  def to_path
    @body.to_path
  end

  def each
    @body.each { |x| yield x }
  end

  def to_io
    @body.to_io
  end

  # called by the writer thread to wake up the original thread (in #initialize)
  def close
    @body.close
    ensure
      @mutex.synchronize { @cv.signal }
  end
end
