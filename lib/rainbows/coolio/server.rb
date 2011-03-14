# -*- encoding: binary -*-
# :enddoc:
class Rainbows::Coolio::Server < Coolio::IO
  CONN = Rainbows::Coolio::CONN
  # CL and MAX will be defined in the corresponding worker loop

  def on_readable
    return if CONN.size >= MAX
    io = @_io.kgio_tryaccept and CL.new(io).attach(LOOP)
  end
end
