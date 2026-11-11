separate (Files.File_System)
function Trash_Files_Directory return String is
   Base    : constant String := Trash_Base_Path;
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
begin
   if Base = "" then
      return "";
   end if;

   case Backend is
      when Trash_Macos_Home =>
         return Base;
      when Trash_Xdg_Data_Home | Trash_Home_Data =>
         return Hostkit.Fs.Join (Base, "files");
      when others =>
         return "";
   end case;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Trash_Files_Directory;
