# -*- encoding: binary -*-
# :enddoc:
class Rainbows::MaxBody::RewindableWrapper < Rainbows::MaxBody::Wrapper
  def initialize(rack_input, limit)
    @orig_limit = limit
    super
  end

  def rewind
    @limit = @orig_limit
    @rbuf = ''
    @input.rewind
  end

  def size
    @input.size
  end
end
