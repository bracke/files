separate (Files.File_System)
function Trash_Files_Directory return String is
   Backend : constant Trash_Backend := Trash_Backend_Of_Current_Environment;
begin
   --  The Recycle Bin's own folder on the system drive (C:\$Recycle.Bin\<SID>):
   --  the trash view lists it together with the bin on every other fixed
   --  drive, from their $I files (Load_Directory_Filtered). It is there once
   --  anything was ever recycled on that drive.
   if Backend = Trash_Windows_Recycle_Bin then
      return
        (if Hostkit.Host.Current = Hostkit.Host.Windows then Hostkit.Trash.Primary_Recycle_Bin_Folder else "");
   end if;

   declare
      Base : constant String := Trash_Base_Path;
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
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return "";
end Trash_Files_Directory;
