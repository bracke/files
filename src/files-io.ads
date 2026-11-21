--  The storage primitives every other unit reads and writes the disk
--  through: bounded and lease-held streams, durable (synced, published)
--  writes, the job records' field bounds, private folders, capped reads and
--  the error keys an I/O failure maps to. Nothing here knows the model,
--  the jobs or the user interface.
package Files.IO is
   pragma Pure;
end Files.IO;
