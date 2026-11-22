package body Files.Operations.Metadata.Testing is

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Metadata.Set_Permissions_For;

end Files.Operations.Metadata.Testing;
