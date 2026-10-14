with Ada.IO_Exceptions;

package body Files.Bounded_Text_IO is
   use Ada.Strings.Unbounded;

   procedure Read_Line
     (File     : in out Ada.Text_IO.File_Type;
      Maximum  : Positive;
      Line     : out Ada.Strings.Unbounded.Unbounded_String;
      Complete : out Boolean)
   is
      Buffer : String (1 .. Maximum);
      Last   : Natural;
   begin
      Line := Null_Unbounded_String;
      Complete := False;
      Ada.Text_IO.Get_Line (File, Buffer, Last);

      if Last < Buffer'Last or else Ada.Text_IO.End_Of_File (File) then
         Line := To_Unbounded_String (Buffer (1 .. Last));
         Complete := True;
      elsif Ada.Text_IO.End_Of_Line (File) then
         --  Get_Line filled the buffer exactly and left the line mark pending.
         Ada.Text_IO.Skip_Line (File);
         Line := To_Unbounded_String (Buffer);
         Complete := True;
      else
         --  Discard the rest of this physical record. Skip_Line raises at an
         --  unterminated final line, but reaching EOF still completes the
         --  discard and the record remains rejected.
         begin
            Ada.Text_IO.Skip_Line (File);
         exception
            when Ada.IO_Exceptions.End_Error => null;
         end;
      end if;
   end Read_Line;
end Files.Bounded_Text_IO;
