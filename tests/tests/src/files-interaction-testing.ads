with Guikit.Input;
with Files.Commands;
with Files.Model;
with Files.Settings;

--  Test-only access to private subprograms of Files.Interaction, kept out of the program.
package Files.Interaction.Testing is

   --  Execute a single command with the follow-ups a settings change needs
   --  (Files.Interaction.Execute_Command): a settings command's own, the UI
   --  state it changed written back, and an open settings pane refreshed.
   --
   --  @param Model Window model to update.
   --  @param Settings Live settings model, updated in place when the command persists state.
   --  @param Settings_Path Central settings file path (empty disables persistence).
   --  @param Command Command identifier to execute.
   --  @param Modifiers Active modifier keys.
   --  @param Result Follow-up flags describing what the command did.
   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result);

end Files.Interaction.Testing;
