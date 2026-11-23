with Ada.Streams;
with Files.IO.Descriptor_Streams;

--  Sequential output streams that create a new regular pathname exclusively.
--  Existing files and links are refused instead of followed or truncated.
package Files.IO.Exclusive_Streams is
   --  A Descriptor_Streams output on a file this stream made (and only it):
   --  it counts what is written, and refuses to write once closed.
   type Output_Stream is new Files.IO.Descriptor_Streams.Output_Stream with private;

   --  Create Path as a new owner-only binary file.
   --  @param Stream Closed stream that will own the new descriptor.
   --  @param Path Pathname that must not already exist.
   --  @raise Ada.IO_Exceptions.Use_Error when something is there, the host
   --    refused, or the new file could not be made owner-only (it is then
   --    removed, or traced when the host refuses that too).
   procedure Create (Stream : in out Output_Stream; Path : String);

   --  Create, telling a taken name apart from every other failure: Name_Taken
   --  is set, and nothing raised, only when the create failed and an entry is
   --  surely there. A file made but not made owner-only raises Use_Error, as
   --  any other failure does, though the host may keep it.
   --  @param Stream Closed stream that will own the new descriptor.
   --  @param Path Pathname that must not already exist.
   --  @param Name_Taken Set when an entry was already there; Stream is then
   --    left closed.
   procedure Create
     (Stream     : in out Output_Stream;
      Path       : String;
      Name_Taken : out Boolean);

   --  Write out buffered bytes and close Stream, raising Use_Error when the
   --  host cannot complete either.
   --  @param Stream Open stream to close.
   procedure Close (Stream : in out Output_Stream);

   --  Best-effort close for exception cleanup; buffered bytes are dropped.
   --  @param Stream Stream whose descriptor should be released.
   procedure Close_Safely (Stream : in out Output_Stream);

   --  @param Stream Stream to inspect.
   --  @return Number of bytes written so far, buffered ones included.
   function Size (Stream : Output_Stream) return Long_Long_Integer;

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

private

   --  @param Stream Stream to inspect.
   --  @return True while Stream owns an open descriptor.
   function Is_Open (Stream : Output_Stream) return Boolean;
   --  Writes are gathered into blocks by the parent (Descriptor_Streams):
   --  records are encoded a field at a time, and a write per field was a
   --  syscall per field.
   type Output_Stream is new Files.IO.Descriptor_Streams.Output_Stream with record
      Length : Long_Long_Integer := 0;
   end record;
end Files.IO.Exclusive_Streams;
