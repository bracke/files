separate (Files.File_System)
function Trash_Backend_Of_Current_Environment return Trash_Backend is
begin
   return Trash_Location_For_Environment.Backend;
end Trash_Backend_Of_Current_Environment;
