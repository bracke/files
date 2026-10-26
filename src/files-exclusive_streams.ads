with Ada.Streams;
with GNAT.OS_Lib;

--  Sequential output streams that create a new regular pathname exclusively.
--  Existing files and links are refused instead of followed or truncated.
package Files.Exclusive_Streams is
   type Output_Stream is new Ada.Streams.Root_Stream_Type with private;

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

   overriding procedure Read
     (Stream : in out Output_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Output_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

private
   --  Writes are gathered into blocks: records are encoded a field at a
   --  time, and a write per field was a syscall per field.
   Block_Size : constant := 16 * 1024;

   type Output_Stream is new Ada.Streams.Root_Stream_Type with record
      Descriptor : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Length     : Long_Long_Integer := 0;
      Block      : Ada.Streams.Stream_Element_Array (1 .. Block_Size);
      Pending    : Ada.Streams.Stream_Element_Offset := 0;
   end record;
end Files.Exclusive_Streams;
