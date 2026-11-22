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

   --  A window samples the host before its first frame and keeps the sample
   --  current (Files.Application.Window_Polls.Sample_Host); a model no window
   --  sampled -- the helper's, a test's -- takes the host to be able to.

   function Trash_Available (Model : Files.Model.Window_Model) return Boolean is
     (not Files.Model.Status_Samples.Host_Sampled (Model)
      or else Files.Model.Status_Samples.Trash_Available (Model));

   function Permissions_Supported (Model : Files.Model.Window_Model) return Boolean is
     (not Files.Model.Status_Samples.Host_Sampled (Model)
      or else Files.Model.Status_Samples.Permissions_Supported (Model));

   function Ownership_Supported (Model : Files.Model.Window_Model) return Boolean is
     (not Files.Model.Status_Samples.Host_Sampled (Model)
      or else Files.Model.Status_Samples.Ownership_Supported (Model));

end Files.Commands.Status;
