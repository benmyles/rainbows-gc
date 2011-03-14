# -*- encoding: binary -*-
# :enddoc:
#
# this is class is specific to Coolio for proxying IO-derived objects
class Rainbows::Coolio::ResponseChunkPipe < Rainbows::Coolio::ResponsePipe
  def on_read(data)
    @client.write("#{data.size.to_s(16)}\r\n")
    @client.write(data)
    @client.write("\r\n")
  end

  def on_close
    @client.write("0\r\n\r\n")
    super
  end
end
