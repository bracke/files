separate (Files.File_System)
function Load_Directory_Generating_Thumbnails
  (Path     : String;
   Settings : Files.Settings.Settings_Model)
   return Directory_Load_Result is
begin
   return Load_Directory_Filtered (Path, Settings, null, Generate_Thumbnails => True);
end Load_Directory_Generating_Thumbnails;
