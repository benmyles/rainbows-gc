# -*- encoding: binary -*-
# :enddoc:
#
# this is class is specific to Coolio for writing large static files
# or proxying IO-derived objects
class Rainbows::Coolio::ResponsePipe < Coolio::IO
  def initialize(io, client, body)
    super(io)
    @client, @body = client, body
  end

  def on_read(data)
    @client.write(data)
  end

  def on_close
    @body.respond_to?(:close) and @body.close
    @client.next!
  end
end
