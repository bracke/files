with Files.File_System.Permissions;
with Files.File_System.Trash;
with Files.Model.Status_Samples;
with Files.Model.History;
with Files.Model.Rename;
with Files.Model.Selection;

package body Files.Commands.Status is

   --  Return whether the model currently shows the platform trash payload
   --  directory rather than an ordinary directory.
   function In_Trash_View (Model : Files.Model.Window_Model) return Boolean is
   begin
      return Files.Model.Current_Is_Trash (Model);
   end In_Trash_View;

   function Status_Of
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Command_Status is separate;

   function Is_Enabled
     (Id    : Command_Id;
      Model : Files.Model.Window_Model)
      return Boolean is (Status_Of (Id, Model).Enabled);

   function Trash_Available (Model : Files.Model.Window_Model) return Boolean is
     (if Files.Model.Status_Samples.Host_Sampled (Model)
      then Files.Model.Status_Samples.Trash_Available (Model)
      else Files.File_System.Trash.Trash_Files_Directory /= "");

   function Permissions_Supported (Model : Files.Model.Window_Model) return Boolean is
     (if Files.Model.Status_Samples.Host_Sampled (Model)
      then Files.Model.Status_Samples.Permissions_Supported (Model)
      else Files.File_System.Permissions.Supports_Permissions);

   function Ownership_Supported (Model : Files.Model.Window_Model) return Boolean is
     (if Files.Model.Status_Samples.Host_Sampled (Model)
      then Files.Model.Status_Samples.Ownership_Supported (Model)
      else Files.File_System.Permissions.Supports_Ownership);

end Files.Commands.Status;
