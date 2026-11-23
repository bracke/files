with Files.Interaction.Testing;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Interaction)
   procedure Test_Settings_Writes_Report_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Blocker  : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "not-a-folder");
      Before   : constant Boolean := Settings.Show_File_Extensions;
   begin
      Files_Suite.Support.Disk.Reset_Root;
      --  No settings file (smoke runs, tests): the toggle applies in memory.
      Files.Interaction.Testing.Execute_Command
        (Model, Settings, "", Files.Commands.Toggle_Show_Extensions_Command, Result => Result);
      Assert (Settings.Show_File_Extensions /= Before and then Files.Model.Last_Error_Key (Model) = "",
              "without a settings file the toggle applies and reports nothing");

      --  A settings file that cannot be written: the change is reported.
      Files_Suite.Support.Disk.Write_File (Blocker, "a file where a folder should be");
      Files.Interaction.Testing.Execute_Command
        (Model, Settings, Files_Suite.Support.Disk.Join (Blocker, "settings.conf"),
         Files.Commands.Cycle_Group_By_Command, Result => Result);
      Assert (Files.Model.Last_Error_Key (Model) /= "", "a settings file that cannot be written is reported");
   end Test_Settings_Writes_Report_Failure;
