with Ada.IO_Exceptions;

package body Files.Bounded_Streams is
   function Input_String
     (Stream     : not null access Ada.Streams.Root_Stream_Type'Class;
      Max_Length : Natural) return String
   is
      First : constant Integer := Integer'Input (Stream);
      Last  : constant Integer := Integer'Input (Stream);
   begin
      if First < Positive'First
        or else Last < First - 1
        or else
          (Last >= First
           and then Long_Long_Integer (Last) - Long_Long_Integer (First) + 1 >
             Long_Long_Integer (Max_Length))
      then
         raise Ada.IO_Exceptions.Data_Error;
      end if;

      declare
         Result : String (First .. Last);
      begin
         String'Read (Stream, Result);
         return Result;
      end;
   end Input_String;
end Files.Bounded_Streams;
