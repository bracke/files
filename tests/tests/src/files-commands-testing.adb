package body Files.Commands.Testing is

   function Text_To_Key (Text : String) return Guikit.Input.Key_Code renames Files.Commands.Text_To_Key;

   function Allowed_With_Root_Selector
     (Id : Command_Id)
      return Boolean renames Files.Commands.Allowed_With_Root_Selector;

   function Allowed_With_Settings_Pane
     (Id : Command_Id)
      return Boolean renames Files.Commands.Allowed_With_Settings_Pane;

   function Is_Valid_Shortcut_Text (Text : String) return Boolean renames Files.Commands.Is_Valid_Shortcut_Text;

   function Shortcut_Override (Id : Command_Id; Is_Set : out Boolean) return Shortcut
     renames Files.Commands.Shortcut_Override;

end Files.Commands.Testing;
