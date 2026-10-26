separate (Files_Suite.Operations)
   --  Every settings change has one policy: what the file cannot hold is
   --  refused, an unchanged one writes nothing, and a save that fails is
   --  reported in the command's result, whichever command made the change.
   procedure Test_Settings_Change_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Group_Mode;
      --  A folder where the settings file would be: no save succeeds.
      Unwritable : constant String := Join (Root, "settings-is-a-folder");
      Settings   : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model      : Files.Model.Window_Model;
      Saved      : Files.Settings.Settings_Write_Result;
      Outcome    : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Unwritable);
      Files.Model.Initialize (Model, Root, Files.File_System.Item_Vectors.Empty_Vector, Root);
      --  Where the column commands are enabled.
      Files.Model.Set_View_Mode (Model, Files.Types.Details);

      Saved := Files.Controller.Commit_Settings (Model, Settings, Settings, Unwritable);
      Assert (Saved.Success, "an unchanged change writes nothing, so nothing fails");

      Outcome :=
        Files.Controller.Execute_Command (Files.Commands.Toggle_Column_Size_Command, Model, Settings, Unwritable);
      Assert (Outcome.Operation.Status = Files.Operations.Operation_Failed, "a column toggle whose save fails says so");
      Outcome := Files.Controller.Execute_Command (Files.Commands.Cycle_Group_By_Command, Model, Settings, Unwritable);
      Assert (Outcome.Operation.Status = Files.Operations.Operation_Failed, "so does cycling the grouping");
      Assert (Settings.Group_By /= Files.Settings.Default_Settings.Group_By,
              "and the change is kept for the session");

      declare
         Before  : constant Files.Settings.Settings_Model := Settings;
         Updated : Files.Settings.Settings_Model := Settings;
      begin
         for Batch in 0 .. 1_000 loop
            exit when not Files.Settings.Loadable (Updated);
            for Index in Batch * 100 + 1 .. Batch * 100 + 100 loop
               Files.Settings.Toggle_Favorite_Path (Updated, "/nowhere/" & Index'Image);
            end loop;
         end loop;
         Assert (not Files.Settings.Loadable (Updated), "the settings file has an entry bound");
         Saved := Files.Controller.Commit_Settings (Model, Settings, Updated, Join (Root, "settings"));
         Assert (not Saved.Success, "a change the file cannot hold is refused");
         Assert (Files.Settings.Same_Content (Settings, Before), "and not applied");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model), "error.settings.full", "the error line says why");
      end;
      Reset_Root;
   end Test_Settings_Change_Policy;
