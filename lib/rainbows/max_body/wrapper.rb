# -*- encoding: binary -*-
# :enddoc:
#
# This is only used for chunked request bodies, which are rare
class Rainbows::MaxBody::Wrapper
  def initialize(rack_input, limit)
    @input, @limit, @rbuf = rack_input, limit, ''
  end

  def each
    while line = gets
      yield line
    end
  end

  # chunked encoding means this method behaves more like readpartial,
  # since Rack does not support a method named "readpartial"
  def read(length = nil, rv = '')
    if length
      if length <= @rbuf.size
        length < 0 and raise ArgumentError, "negative length #{length} given"
        rv.replace(@rbuf.slice!(0, length))
      elsif @rbuf.empty?
        checked_read(length, rv) or return
      else
        rv.replace(@rbuf.slice!(0, @rbuf.size))
      end
      rv.empty? && length != 0 ? nil : rv
    else
      rv.replace(read_all)
    end
  end

  def gets
    sep = $/
    if sep.nil?
      rv = read_all
      return rv.empty? ? nil : rv
    end
    re = /\A(.*?#{Regexp.escape(sep)})/

    begin
      @rbuf.sub!(re, '') and return $1

      if tmp = checked_read(16384)
        @rbuf << tmp
      elsif @rbuf.empty? # EOF
        return nil
      else # EOF, return whatever is left
        return @rbuf.slice!(0, @rbuf.size)
      end
    end while true
  end

  def checked_read(length = 16384, buf = '')
    if @input.read(length, buf)
      throw :rainbows_EFBIG if ((@limit -= buf.size) < 0)
      return buf
    end
  end

  def read_all
    rv = @rbuf.slice!(0, @rbuf.size)
    tmp = ''
    while checked_read(16384, tmp)
      rv << tmp
    end
    rv
  end
end
