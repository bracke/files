with Ada.Streams;
with Files.Descriptor_Streams;

--  Sequential output streams that create a new regular pathname exclusively.
--  Existing files and links are refused instead of followed or truncated.
package Files.Exclusive_Streams is
   --  A Descriptor_Streams output on a file this stream made (and only it):
   --  it counts what is written, and refuses to write once closed.
   type Output_Stream is new Files.Descriptor_Streams.Output_Stream with private;

   --  Create Path as a new owner-only binary file.
   --  @param Stream Closed stream that will own the new descriptor.
   --  @param Path Pathname that must not already exist.
   procedure Create (Stream : in out Output_Stream; Path : String);

   --  Write out buffered bytes and close Stream, raising Use_Error when the
   --  host cannot complete either.
   --  @param Stream Open stream to close.
   procedure Close (Stream : in out Output_Stream);

   --  Best-effort close for exception cleanup; buffered bytes are dropped.
   --  @param Stream Stream whose descriptor should be released.
   procedure Close_Safely (Stream : in out Output_Stream);

   --  @param Stream Stream to inspect.
   --  @return True while Stream owns an open descriptor.
   function Is_Open (Stream : Output_Stream) return Boolean;

   --  @param Stream Stream to inspect.
   --  @return Number of bytes written so far, buffered ones included.
   function Size (Stream : Output_Stream) return Long_Long_Integer;

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

private
   --  Writes are gathered into blocks by the parent (Descriptor_Streams):
   --  records are encoded a field at a time, and a write per field was a
   --  syscall per field.
   type Output_Stream is new Files.Descriptor_Streams.Output_Stream with record
      Length : Long_Long_Integer := 0;
   end record;
end Files.Exclusive_Streams;
