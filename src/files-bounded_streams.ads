with Ada.Streams;

package Files.Bounded_Streams is
   --  The bounds the background jobs' records share: a path, a record's
   --  header, an identity or revision token. One set, so a field one writer
   --  may write is one every reader takes.
   Max_Path_Length   : constant := 32 * 1024;
   Max_Header_Length : constant := 128;
   Max_Token_Length  : constant := 2 * 1024;

   --  String'Output, refused (Use_Error) when longer than its reader takes.
   --  @param Stream Destination stream.
   --  @param Value String to encode.
   --  @param Max_Length Largest length the reader accepts.
   procedure Output_String
     (Stream     : not null access Ada.Streams.Root_Stream_Type'Class;
      Value      : String;
      Max_Length : Natural);

   --  @param Stream Stream containing the bounds and bytes emitted by String'Output.
   --  @param Max_Length Largest accepted string length.
   --  @return The decoded string; malformed bounds or excess length raise Data_Error.
   function Input_String
     (Stream     : not null access Ada.Streams.Root_Stream_Type'Class;
      Max_Length : Natural) return String;
end Files.Bounded_Streams;
