separate (Files.File_System.Trash.Move_To_Trash)
--  Create only the generic parent with the process umask. The trash root
--  and both payload directories are owner-only before any name or
--  metadata is placed in them.
procedure Prepare_Directories is
begin
   begin
      Files.IO.Errors.Clear_Os_Error;
      Files.IO.Fs_Primitives.Create_Path (Files.IO.Fs_Primitives.Parent_Directory (Base));
   exception
      when others =>
         Files.IO.Errors.Capture;
         raise;
   end;
   Files.IO.Private_Directories.Ensure (Base);
   if Files_Dir /= Base then
      Files.IO.Private_Directories.Ensure (Files_Dir);
   end if;
   if Info_Dir /= "" then
      Files.IO.Private_Directories.Ensure (Info_Dir);
   end if;
end Prepare_Directories;
