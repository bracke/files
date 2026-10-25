separate (Files_Suite.Interaction)
   procedure Test_Path_Star_Click_Toggles_Current_Dir (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Path     : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "path-star.conf");
      Current  : constant String := Files.Model.Current_Path (Model);
      Star     : constant Files.Rendering.Path_Favorite_Star_Bounds :=
        Files.Rendering.Path_Favorite_Star_Region (Window_W, Line);

      --  Rebuild the real snapshot/frame each time and translate a click at the
      --  star's center, so the assertion drives the same seam the shell drives.
      function Star_Action return Files.Events.Input_Action is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      begin
         return
           Files.Events.Translate_Click
             (Snapshot, Frame,
              Star.X + Star.Width / 2,
              Star.Y + Star.Height / 2,
              Window_W, Window_H, Line_Height => Line);
      end Star_Action;
   begin
      Files_Suite.Support.Reset_Root;
      Assert (Star.Visible, "the path-bar star is laid out at the default window size");
      Assert (not Has_Favorite (Settings, Current), "the current directory starts unfavorited");

      --  The star coordinate resolves to the favorite-toggle action, not to
      --  focusing the path field or navigating a breadcrumb.
      declare
         Action : constant Files.Events.Input_Action := Star_Action;
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Path_Favorite_Toggle_Input_Action,
            "a click on the empty path star translates to the favorite-toggle action");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (Has_Favorite (Settings, Current), "clicking the empty star favorites the current directory");
      Assert (Result.Settings_Changed, "toggling the path star reports a settings change");
      Assert (Ada.Directories.Exists (Path), "toggling the path star persists the settings file");
      Assert
        (Files.Model.Focus (Model) /= Files.Types.Focus_Path_Input,
         "toggling the path star does not focus the path input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Current,
         "toggling the path star does not navigate away from the current directory");

      --  The snapshot now reports the favorited state (filled star); clicking
      --  the same zone again removes the favorite.
      declare
         Action : constant Files.Events.Input_Action := Star_Action;
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Path_Favorite_Toggle_Input_Action,
            "a second click on the now-filled path star is still the favorite-toggle action");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, Path, Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Has_Favorite (Settings, Current), "clicking the filled star unfavorites the current directory");
   end Test_Path_Star_Click_Toggles_Current_Dir;
