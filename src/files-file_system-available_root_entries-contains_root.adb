separate (Files.File_System.Available_Root_Entries)
function Contains_Root (Path : String) return Boolean is
begin
   for Root of Roots loop
      if To_String (Root.Path) = Path then
         return True;
      end if;
   end loop;

   return False;
end Contains_Root;
