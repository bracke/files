separate (Files.File_System)
function Valid_Original_Path (Path : String) return Boolean is
begin
   if Path = "" or else not GNAT.OS_Lib.Is_Absolute_Path (Path) then
      return False;
   end if;
   for Value of Path loop
      if Value = ASCII.NUL then
         return False;
      end if;
   end loop;
   return True;
exception
   when others =>
      return False;
end Valid_Original_Path;
