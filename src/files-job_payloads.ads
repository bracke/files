with Ada.Streams;

with Files.Items;
with Files.Jobs.Records;
with Files.Operation_Results;
with Files.Settings;

--  The payloads background jobs hand between the window and a helper:
--  settings snapshots, directory listings with their thumbnails, and
--  operation results, each bounded and validated as it is read. The wire
--  primitives and limits they build on are Files.Jobs.Records'.
package Files.Job_Payloads is
   --  The thumbnail pixels one refresh may carry: half the transport, about
   --  16,000 thumbnails, so a folder of more images still fits the rest.
   Max_Thumbnail_Transport_Bytes : constant := Files.Jobs.Records.Max_Transport_Bytes / 2;

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

   --  Encode a bounded vector of directory items and thumbnail data.
   --  @param Stream Destination stream.
   --  @param Value Items to encode.
   procedure Write_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Items.Item_Vectors.Vector);

   --  Decode a bounded vector of directory items and thumbnail data.
   --  @param Stream Source stream.
   --  @return Decoded items.
   function Read_Items
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Items.Item_Vectors.Vector;

   --  Encode a background operation result.
   --  @param Stream Destination stream.
   --  @param Value Result to encode.
   procedure Write_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Value : Files.Operation_Results.Operation_Result);

   --  Decode a bounded background operation result.
   --  @param Stream Source stream.
   --  @return Decoded result.
   function Read_Operation_Result
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class)
      return Files.Operation_Results.Operation_Result;

   --  Drop the thumbnails past Max_Thumbnail_Transport_Bytes, in order: the
   --  items keep their icons, and the transport stays inside its bound
   --  instead of failing the whole read of a large photo folder.
   --
   --  @param Items Items about to be written to a transport.
   procedure Fit_Thumbnails (Items : in out Files.Items.Item_Vectors.Vector);

end Files.Job_Payloads;
