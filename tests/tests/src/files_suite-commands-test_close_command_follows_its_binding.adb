with Files.Model.Command_Palette;
with Files_Suite.Support.Guards;
separate (Files_Suite.Commands)
   --  Escape is only the default key of Close_Overlay_Command ("palette.close"):
   --  rebound, the new key closes the top overlay and cancels an edit, and
   --  Escape no longer does. By key or as a command it answers alike.
   procedure Test_Close_Command_Follows_Its_Binding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  Clears the override this test sets, on an assertion failure too.
      Shortcuts : Files_Suite.Support.Guards.Shortcut_Guard;
      pragma Unreferenced (Shortcuts);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Files.Commands.Reset_Shortcut_Overrides;

      --  By its default key and as a command, closing answers the same.
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "Escape closes the palette by default");
      declare
         By_Key : constant Files.Controller.Controller_Status := Result.Status;
      begin
         Files.Model.Command_Palette.Open (Model);
         Result :=
           Files.Controller.Execute_Non_Settings_Command (Files.Commands.Close_Overlay_Command, Model, Settings);
         Assert (not Files.Model.Command_Palette.Is_Open (Model), "the close command closes the palette");
         Files_Suite.Support.Assert_Equal (Result.Status, By_Key, "by key or as a command, one status");
         Files_Suite.Support.Assert_Equal
           (Result.Command, Files.Commands.Close_Overlay_Command, "and one command");
      end;

      --  Rebound to F9: F9 closes, Escape leaves the palette open.
      Files.Commands.Set_Shortcut_Override
        (Files.Commands.Close_Overlay_Command, (Present => True, Key => Guikit.Input.Key_F9, others => <>));
      Files.Model.Command_Palette.Open (Model);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (Files.Model.Command_Palette.Is_Open (Model), "Escape no longer closes once the close key is rebound");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F9);
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "the rebound key closes the palette");
      Files_Suite.Support.Assert_Equal
        (Result.Command, Files.Commands.Close_Overlay_Command, "the rebound key runs the close command");

      --  The rebound key cancels an edit too.
      Files.Model.Selection.Select_Visible (Model, 2);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Assert (Files.Model.Rename.Is_Active (Model), "F2 starts a rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F9);
      Assert (not Files.Model.Rename.Is_Active (Model), "the rebound close key cancels the rename");
      Files.Commands.Reset_Shortcut_Overrides;
   end Test_Close_Command_Follows_Its_Binding;
