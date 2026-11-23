with Ada.Streams;
with Files.IO.Record_Fields;

with Files.File_System_Types;
with Files.Protocol_Names;
with Files.Types;

--  Bounded wire primitives shared by private background-job transports.
--  The payloads of particular jobs (settings, listings, operation results)
--  are encoded above this layer, in Files.Job_Payloads.
package Files.Jobs.Records is
   Max_Transport_Bytes : constant := 512 * 1024 * 1024;

   Max_Path_Length : constant := Files.IO.Record_Fields.Max_Path_Length;
   Max_Text_Length : constant := 64 * 1024;
   Max_Error_Length : constant := 256;

   --  Publish a helper's result in its job directory: Write fills the staged
   --  file, which is size-checked, closed and published whole and durably
   --  under Name, where the window reads it. A failure raises Use_Error
   --  saying which step failed and what was left on disk.
   --
   --  @param Directory The job's private directory.
   --  @param Write Writes the result's records.
   --  @param Stream Where Write writes.
   --  @param Name The result's published name, for a helper that publishes
   --    several.
   procedure Publish_Result
     (Directory : String;
      Write     : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class);
      Name      : String := Files.Protocol_Names.Result_File);

   --  Reject an oversized transport before decoding any heap-owning fields.
   --  @param Size Encoded transport size to validate.
   procedure Validate_Size (Size : Long_Long_Integer);

   --  Encode a directory change signature.
   --  @param Stream Destination stream.
   --  @param Value Signature to encode.
   procedure Write_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System_Types.Directory_Signature);

   --  Decode a bounded directory change signature.
   --  @param Stream Source stream.
   --  @return Decoded signature.
   function Read_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System_Types.Directory_Signature;

   --  The most path moves one record carries (Write_Path_Moves).
   Max_Path_Moves : constant := 100_000;

   --  Encode the renames, moves and removals a helper made, each as its kind,
   --  its old path and its new one (empty for a removal). At most
   --  Max_Path_Moves, as Read_Path_Moves accepts: past that the labels of the
   --  rest do not follow, but the rest of the record still reads back.
   --  A move whose To does not match its Kind raises Use_Error.
   --  @param Stream Destination stream.
   --  @param Value Moves to encode, in order.
   procedure Write_Path_Moves
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value  : Files.Types.Path_Move_Vectors.Vector);

   --  Decode the moves Write_Path_Moves wrote. A count past Max_Path_Moves,
   --  an unknown kind, an empty old path, or a new path that does not match
   --  the kind raises Data_Error.
   --  @param Stream Source stream.
   --  @return Decoded moves, in order.
   function Read_Path_Moves
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Types.Path_Move_Vectors.Vector;

end Files.Jobs.Records;
