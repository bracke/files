with Ada.Streams;

with Files.File_System;
with Files.Operations;
with Files.Settings;

--  Bounded wire primitives shared by private background-job transports.
package Files.Job_Records is
   Max_Transport_Bytes : constant := 512 * 1024 * 1024;
   Max_Path_Length : constant := 32 * 1024;
   Max_Text_Length : constant := 64 * 1024;
   Max_Error_Length : constant := 256;

   --  Reject an oversized transport before decoding any heap-owning fields.
   --  @param Size Encoded transport size to validate.
   procedure Validate_Size (Size : Long_Long_Integer);

   --  Write a string after enforcing its protocol-specific bound.
   --  @param Stream Destination stream.
   --  @param Value String to encode.
   --  @param Maximum Maximum permitted byte length.
   procedure Write_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : String;
      Maximum : Natural);

   --  Read a string without allocating beyond its protocol-specific bound.
   --  @param Stream Source stream.
   --  @param Maximum Maximum permitted byte length.
   --  @return Decoded string.
   function Read_String
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Maximum : Natural) return String;

   --  Encode settings through their bounded, stable textual representation.
   --  @param Stream Destination stream.
   --  @param Value Settings snapshot to encode.
   procedure Write_Settings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Settings.Settings_Model);

   --  Decode and validate a bounded textual settings snapshot.
   --  @param Stream Source stream.
   --  @return Parsed settings snapshot.
   function Read_Settings
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Settings.Settings_Model;

   --  Encode a directory change signature.
   --  @param Stream Destination stream.
   --  @param Value Signature to encode.
   procedure Write_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System.Directory_Signature);

   --  Decode a bounded directory change signature.
   --  @param Stream Source stream.
   --  @return Decoded signature.
   function Read_Signature
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System.Directory_Signature;

   --  Encode a bounded vector of directory items and thumbnail data.
   --  @param Stream Destination stream.
   --  @param Value Items to encode.
   procedure Write_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.File_System.Item_Vectors.Vector);

   --  Decode a bounded vector of directory items and thumbnail data.
   --  @param Stream Source stream.
   --  @return Decoded items.
   function Read_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.File_System.Item_Vectors.Vector;

   --  Encode a background operation result.
   --  @param Stream Destination stream.
   --  @param Value Result to encode.
   procedure Write_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Operations.Operation_Result);

   --  Decode a bounded background operation result.
   --  @param Stream Source stream.
   --  @return Decoded result.
   function Read_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Operations.Operation_Result;
end Files.Job_Records;
