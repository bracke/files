package body Files.Operations.Metadata.Testing is

   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Metadata.Set_Permissions_For;

   function Set_Ownership_For
     (Model    : in out Files.Model.Window_Model;
      User_Id  : Files.Types.Account_Id;
      Group_Id : Files.Types.Account_Id;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
     renames Files.Operations.Metadata.Set_Ownership_For;

end Files.Operations.Metadata.Testing;
