separate (Files.File_System)
function Kind_From_Path
  (Full : String)
   return Files.Types.Item_Kind
is
begin
   if Hostkit.Fs.Is_Link (Full) then
      return Files.Types.Symlink_Item;
   end if;

   case Files.Fs_Primitives.Kind (Full) is
      when Ada.Directories.Directory =>
         return Files.Types.Directory_Item;
      when Ada.Directories.Ordinary_File =>
         if Hostkit.Fs.Is_Executable (Full) then
            return Files.Types.Executable_Item;
         end if;
         return Files.Types.Regular_File_Item;
      when Ada.Directories.Special_File =>
         return Files.Types.Other_Item;
   end case;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return Files.Types.Unknown_Item;
end Kind_From_Path;
