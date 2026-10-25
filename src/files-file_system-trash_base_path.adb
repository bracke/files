separate (Files.File_System)
function Trash_Base_Path return String is
begin
   return To_String (Trash_Location_For_Environment.Base);
end Trash_Base_Path;
