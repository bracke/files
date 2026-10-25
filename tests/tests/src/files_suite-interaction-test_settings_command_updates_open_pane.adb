separate (Files_Suite.Interaction)
   procedure Test_Settings_Command_Updates_Open_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Run (Command : Files.Commands.Command_Id) is
      begin
         Files.Interaction.Execute_Command
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Command           => Command,
            Current_Font_Size => Base_Font,
            Result            => Result);
      end Run;

      function Shown (Setting : Files.Settings.Scalar_Setting) return String is
        (Ada.Strings.Unbounded.To_String (Files.Model.Settings_Draft_Of (Model).Scalars (Setting)));
   begin
      Run (Files.Commands.Toggle_Settings_Pane_Command);
      Assert (Files.Model.Settings_Pane_Is_Open (Model), "the settings pane is open");
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Show_Hidden_Files_Setting), "false", "the pane starts with hidden files off");

      --  Edit another field in the pane, then run a settings command over it.
      declare
         Edited : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
      begin
         Edited.Scalars (Files.Settings.Default_View_Mode_Setting) :=
           Ada.Strings.Unbounded.To_Unbounded_String ("details");
         Files.Model.Set_Settings_Draft (Model, Edited);
      end;
      Run (Files.Commands.Toggle_Hidden_Files_Command);
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Default_View_Mode_Setting), "details",
         "an edit in progress in the pane survives the command");
      Assert (Settings.Show_Hidden_Files, "the command turns hidden files on");
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Show_Hidden_Files_Setting), "true",
         "the open pane shows the command's change, so its next save keeps it");

      --  Saving the pane now writes the new value, not the one it opened with.
      declare
         Applied : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Draft_Of (Model));
      begin
         Assert (Applied.Settings.Show_Hidden_Files, "applying the pane keeps hidden files on");
      end;

      --  Reset from the palette is the pane's Reset button: defaults, saved.
      Run (Files.Commands.Reset_Settings_Command);
      Assert (not Settings.Show_Hidden_Files, "the reset command returns the settings to their defaults");
      Files_Suite.Support.Assert_Equal
        (Shown (Files.Settings.Default_View_Mode_Setting),
         Files.Settings.Scalar_Text (Files.Settings.Default_Settings, Files.Settings.Default_View_Mode_Setting),
         "the pane shows the defaults after the reset");
   end Test_Settings_Command_Updates_Open_Pane;
