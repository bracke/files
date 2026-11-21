with Ada.Streams;
with Hostkit.Lease_Files;

--  Ada stream view of a validated, process-held Hostkit file lease.
package Files.IO.Lease_Streams is

   type Input_Stream is new Ada.Streams.Root_Stream_Type with private;

   overriding procedure Read
     (Stream : in out Input_Stream;
      Item   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset);

   overriding procedure Write
     (Stream : in out Input_Stream;
      Item   : Ada.Streams.Stream_Element_Array);

   --  Open Path without following links and hold a shared read lease until
   --  Release.  The returned stream is pinned to that opened file even if its
   --  pathname is subsequently replaced.
   --  @param Path File to validate and open.
   --  @param Item Stream that owns the resulting lease.
   --  @return Opened on success, otherwise the Hostkit refusal or error.
   function Open
     (Path : String;
      Item : in out Input_Stream)
      return Hostkit.Lease_Files.Open_Outcome;

   --  @param Item Stream whose lease to release and position to reset.
   procedure Release (Item : in out Input_Stream);

   --  @param Item Open input stream.
   --  @return Size pinned when Item was opened, or -1 when it is not open.
   function Size (Item : Input_Stream) return Long_Long_Integer;

   --  @param Item Open input stream.
   --  @return True when all pinned bytes have been consumed.
   function End_Of_Stream (Item : Input_Stream) return Boolean;

   --  Read one transport record whole, the one way every job reads its
   --  records: open Path under its lease, refuse it past Max_Bytes, check its
   --  Header (String'Output; none when ""), read the body, require the end of
   --  the stream (unless Whole is False) and a consistent value, and release
   --  the lease on every path. Raises Ada.IO_Exceptions.Data_Error for a
   --  record that fails any of it.
   generic
      type Item is private;
      --  Read the body's fields from Stream into Value.
      with procedure Read_Body
        (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
         Value  : out Item);
      --  Whether Value is one a writer could have produced.
      with function Is_Consistent (Value : Item) return Boolean;
      --  False reads only the record's leading fields: a poll that needs its
      --  first few, not the rest.
      Whole : Boolean := True;
   --  @param Path The record's file.
   --  @param Header Its leading String'Output header, or "" for none.
   --  @param Max_Bytes The largest record accepted.
   --  @return The value read.
   function Read_Record
     (Path      : String;
      Header    : String;
      Max_Bytes : Long_Long_Integer := Long_Long_Integer'Last)
      return Item;

   --  Whether Path holds exactly Bytes: read under a shared lease, released
   --  on every path. A file that cannot be opened, or any failure while it is
   --  read, answers False (a failure is traced).
   --
   --  @param Path The marker file.
   --  @param Bytes Its whole expected content.
   --  @return True when the file's size and content are Bytes.
   function Holds_Exactly (Path : String; Bytes : Ada.Streams.Stream_Element_Array) return Boolean;

   --  How Write_Marker left a marker file: Marker_Written, created by this
   --  call holding Bytes; Marker_Exists, something already had the name and
   --  nothing was written; Marker_Torn, created by this call but the write
   --  failed, so it is the caller's to remove; Marker_Not_Created, locking
   --  unavailable or an error.
   type Marker_Write is (Marker_Written, Marker_Exists, Marker_Torn, Marker_Not_Created);

   --  Create Path exclusively and write Bytes into it, releasing the lease
   --  before it returns (or raises).
   --
   --  @param Path The marker file to create.
   --  @param Bytes Its whole content.
   --  @return How the file was left.
   function Write_Marker (Path : String; Bytes : Ada.Streams.Stream_Element_Array) return Marker_Write;

private
   --  Read ahead in blocks: a record is decoded a field (often a byte) at a
   --  time, and a read per field was a syscall per field.
   Block_Size : constant := 16 * 1024;

   type Input_Stream is new Ada.Streams.Root_Stream_Type with record
      Handle   : Hostkit.Lease_Files.Lease;
      Position : Ada.Streams.Stream_Element_Offset := 0;
      Length   : Ada.Streams.Stream_Element_Offset := 0;
      --  The file's bytes from Block_Start, Block_Count of them.
      Block       : Ada.Streams.Stream_Element_Array (1 .. Block_Size);
      Block_Start : Ada.Streams.Stream_Element_Offset := 0;
      Block_Count : Ada.Streams.Stream_Element_Offset := 0;
   end record;
end Files.IO.Lease_Streams;
