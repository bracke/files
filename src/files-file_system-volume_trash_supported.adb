with Hostkit.Process;

separate (Files.File_System)
function Volume_Trash_Supported return Boolean is
   Uid : Natural;
begin
   return Trash_Backend_Of_Current_Environment in Trash_Xdg_Data_Home | Trash_Home_Data
     and then Files_Config.Alire_Host_OS /= "windows"
     and then Hostkit.Process.Current_User_Id (Uid);
exception
   when others => return False;
end Volume_Trash_Supported;
