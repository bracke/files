separate (Files.File_System.Trash)
function Trash_Files_Directory return String is
   --  One reading of the environment for both the backend and the base:
   --  every snapshot asks (the Go to Trash command's status).
   Location : constant Trash_Location := Trash_Location_For_Environment;
   Backend  : constant Trash_Backend := Location.Backend;
begin
   --  The Recycle Bin's own folder on the system drive (C:\$Recycle.Bin\<SID>):
   --  the trash view lists it together with the bin on every other fixed
   --  drive, from their $I files (Load_Directory_Filtered). It is there once
   --  anything was ever recycled on that drive, and then stays where it is
   --  for this process's user, so a folder found is asked of the host once.
   if Backend = Trash_Windows_Recycle_Bin then
      if Hostkit.Host.Current /= Hostkit.Host.Windows then
         return "";
      end if;
      declare
         Known : constant String := Primary_Recycle_Bin.Get;
      begin
         if Known /= "" then
            return Known;
         end if;
      end;
      declare
         Found : constant String := Hostkit.Trash.Primary_Recycle_Bin_Folder;
      begin
         if Found /= "" then
            Primary_Recycle_Bin.Set (Found);
         end if;
         return Found;
      end;
   end if;

   declare
      Base : constant String := To_String (Location.Base);
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
