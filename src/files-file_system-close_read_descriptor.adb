separate (Files.File_System)
procedure Close_Read_Descriptor
  (File : in out GNAT.OS_Lib.File_Descriptor)
is
begin
   if File /= GNAT.OS_Lib.Invalid_FD then
      GNAT.OS_Lib.Close (File);
      File := GNAT.OS_Lib.Invalid_FD;
   end if;
exception
   when others =>
      File := GNAT.OS_Lib.Invalid_FD;
end Close_Read_Descriptor;
