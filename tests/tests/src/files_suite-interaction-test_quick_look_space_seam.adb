separate (Files_Suite.Interaction)
   procedure Test_Quick_Look_Space_Seam (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      No_Mod   : Guikit.Input.Modifier_Set renames Guikit.Input.No_Modifiers;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;

      procedure Press_Space
        (Model  : in out Files.Model.Window_Model;
         Result : out Files.Interaction.Interaction_Result) is
      begin
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_Space,
            Modifiers         => No_Mod,
            Current_Font_Size => Base_Font,
            Result            => Result);
      end Press_Space;
   begin
      --  (1) Single selection, grid focused: Space opens Quick Look, the snapshot
      --  carries it, and the parallel space character is dropped from type-ahead.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Alpha.txt");
         Press_Space (Model, Result);
         Assert (Files.Model.Quick_Look_Is_Open (Model), "Space opens Quick Look for a single selection");
         Assert (Result.Clear_Pending_Text, "the grid Space shortcut drops the parallel type-ahead space");
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
         begin
            Assert (Snapshot.Quick_Look_Open, "the snapshot carries the open Quick Look overlay");
         end;

         --  (2) Space again closes it.
         Press_Space (Model, Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Space again closes Quick Look");

         --  (3) Reopen, then Escape closes it.
         Press_Space (Model, Result);
         Assert (Files.Model.Quick_Look_Is_Open (Model), "Space reopens Quick Look");
         Files.Interaction.Handle_Key
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Key               => Guikit.Input.Key_Escape,
            Modifiers         => No_Mod,
            Current_Font_Size => Base_Font,
            Result            => Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Escape closes Quick Look");
      end;

      --  (4) No selection: Space does not open Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Model.Deselect_All (Model);
         Press_Space (Model, Result);
         Assert (not Files.Model.Quick_Look_Is_Open (Model), "Space with no selection does not open Quick Look");
      end;

      --  (5) Multi-selection: Space does not open Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files.Model.Select_All_Visible (Model);
         Assert (Files.Model.Selected_Count (Model) > 1, "the sample model has more than one selectable item");
         Press_Space (Model, Result);
         Assert
           (not Files.Model.Quick_Look_Is_Open (Model),
            "Space with more than one item selected does not open Quick Look");
      end;

      --  (6) Focused text field: Space types a space rather than opening Quick Look.
      declare
         Model  : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
         Result : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Select_Name (Model, "Alpha.txt");
         Files.Model.Focus_Filter_Input (Model);
         Press_Space (Model, Result);
         Assert
           (not Files.Model.Quick_Look_Is_Open (Model),
            "Space in a focused text field does not open Quick Look");
         Assert
           (not Result.Clear_Pending_Text,
            "Space in a focused field keeps its character event so it types a space");
         declare
            Typed : constant Files.Controller.Controller_Result :=
              Files.Controller.Append_Focused_Text (Model, " ");
         begin
            Files_Suite.Support.Assert_Equal
              (Typed.Status, Files.Controller.Controller_Text_Updated,
               "the space character types into the focused filter input (status)");
            Files_Suite.Support.Assert_Equal
              (Files.Model.Filter_Text (Model),
               " ",
               "the space character types into the focused filter input");
         end;
      end;
   end Test_Quick_Look_Space_Seam;
