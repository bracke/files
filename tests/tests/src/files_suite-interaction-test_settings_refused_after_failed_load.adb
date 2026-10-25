separate (Files_Suite.Interaction)
   --  A session whose settings file could not be loaded runs on defaults with
   --  no settings path, so it never overwrites the file. Unlike a session that
   --  asked for no persistence (an empty path), it must not let changes look
   --  saved: each applies for the session and reports that it was not saved.
   procedure Test_Settings_Refused_After_Failed_Load (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Before   : constant Boolean := Settings.Show_File_Extensions;
   begin
      Settings.Persistence_Refused := True;
      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Show_Extensions_Command, Base_Font, Result => Result);
      Assert (Settings.Show_File_Extensions /= Before, "the toggle still applies for the session");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.settings.not_persisted",
         "the toggle reports that the settings are not being saved");

      Files.Model.Set_Error (Model, "");
      Files.Interaction.Execute_Command
        (Model, Settings, "", Files.Commands.Cycle_Group_By_Command, Base_Font, Result => Result);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.settings.not_persisted",
         "every settings write reports it, not only the toggles");
   end Test_Settings_Refused_After_Failed_Load;
