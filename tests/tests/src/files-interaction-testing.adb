package body Files.Interaction.Testing is

   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result)
     renames Files.Interaction.Execute_Command;

end Files.Interaction.Testing;
