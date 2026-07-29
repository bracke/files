separate (Files.Operations)
   function Navigate_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Trash_Dir : constant String := Files.File_System.Trash_Files_Directory;
   begin
      if Trash_Dir = "" then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable", Trash_Dir);
      end if;

      return Load_And_Navigate (Model, Settings, Trash_Dir);
   end Navigate_Trash;
