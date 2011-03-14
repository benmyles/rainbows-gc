# -*- encoding: binary -*-
module Rainbows::EventMachine::Server # :nodoc: all
  def close
    detach
    @io.close
  end

  # CL, CUR and MAX will be set when worker_loop starts
  def notify_readable
    return if CUR.size >= MAX
    io = @io.kgio_tryaccept or return
    sig = EM.attach_fd(io.fileno, false)
    CUR[sig] = CL.new(sig, io)
  end
end
