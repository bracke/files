with Ada.Streams;

package Files.Bounded_Streams is
   --  @param Stream Stream containing the bounds and bytes emitted by String'Output.
   --  @param Max_Length Largest accepted string length.
   --  @return The decoded string; malformed bounds or excess length raise Data_Error.
   function Input_String
     (Stream     : not null access Ada.Streams.Root_Stream_Type'Class;
      Max_Length : Natural) return String;
end Files.Bounded_Streams;
