separate (Files.File_System)
function Ends_With_Whitespace (Name : String) return Boolean is
   Position : Natural := 0;
   Length   : Natural;
   Last     : Boolean := False;
begin
   while Position < Name'Length loop
      Length := Guikit.Utf8.Whitespace_Separator_Length (Name, Position);
      Last := Length > 0 and then Position + Length = Name'Length;
      if Length = 0 then
         declare
            Next_Position : constant Natural := Guikit.Utf8.Editing.Next_Boundary (Name, Position);
         begin
            if Next_Position <= Position then
               return False;
            end if;

            Position := Next_Position;
         end;
      else
         Position := Position + Length;
      end if;
   end loop;

   return Last;
end Ends_With_Whitespace;
