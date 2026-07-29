separate (Files.File_System)
   function Is_All_Whitespace (Name : String) return Boolean is
      Position : Natural := 0;
      Length   : Natural;
   begin
      if Name = "" then
         return True;
      end if;

      while Position < Name'Length loop
         Length := Files.UTF8.Whitespace_Separator_Length (Name, Position);
         if Length = 0 then
            return False;
         end if;

         Position := Position + Length;
      end loop;

      return True;
   end Is_All_Whitespace;
