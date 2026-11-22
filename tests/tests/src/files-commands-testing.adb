package body Files.Commands.Testing is

   function Text_To_Key (Text : String) return Guikit.Input.Key_Code renames Files.Commands.Text_To_Key;

   function Allowed_With_Root_Selector
     (Id : Command_Id)
      return Boolean renames Files.Commands.Allowed_With_Root_Selector;

   function Allowed_With_Settings_Pane
     (Id : Command_Id)
      return Boolean renames Files.Commands.Allowed_With_Settings_Pane;

end Files.Commands.Testing;
