with Files.Model;
with Files.Settings;

--  Test access to Files.Operations.Metadata's private part.
package Files.Operations.Metadata.Testing is

   --  Files.Operations.Metadata.Set_Permissions_For.
   --  @param Model Window model whose selected item's mode is changed.
   --  @param New_Mode POSIX permission bits (low 12 bits) to apply.
   --  @param Settings Settings model used for directory reload classification.
   --  @return Structured operation result.
   function Set_Permissions_For
     (Model    : in out Files.Model.Window_Model;
      New_Mode : Natural;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result;

end Files.Operations.Metadata.Testing;
