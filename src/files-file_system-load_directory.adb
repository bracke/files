separate (Files.File_System)
function Load_Directory
  (Path     : String;
   Settings : Files.Settings.Settings_Model)
   return Directory_Load_Result is
begin
   return Load_Directory_Filtered (Path, Settings, null);
end Load_Directory;
