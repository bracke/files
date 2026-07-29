separate (Files.File_System)
   function Trash_Backend_Of_Current_Environment return Trash_Backend is
   begin
      return Trash_Backend_For_Base;
   end Trash_Backend_Of_Current_Environment;
