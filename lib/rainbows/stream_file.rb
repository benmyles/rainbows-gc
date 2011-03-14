# -*- encoding: binary -*-
# :enddoc:

# Used to keep track of file offsets in IO#trysendfile + evented
# models.  We always maintain our own file offsets in userspace because
# because sendfile() implementations offer pread()-like idempotency for
# concurrency (multiple clients can read the same underlying file handle).
class Rainbows::StreamFile < Struct.new(:offset, :count, :to_io, :body)
  def close
    body.close if body.respond_to?(:close)
    to_io.close unless to_io.closed?
    self.to_io = nil
  end
end
