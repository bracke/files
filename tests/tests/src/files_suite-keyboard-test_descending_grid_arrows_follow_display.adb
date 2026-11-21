with Files.Preference_Types;
with Files.Input_Actions;
with Files.Operation_Results;
with Files_Suite.Support.Disk;
with Files_Suite.Support.Models;
separate (Files_Suite.Keyboard)
   procedure Test_Descending_Grid_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Disk.Join (Files_Suite.Support.Disk.Root, "nav-desc-grid");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;

      function Display_Position_Of (Name : String) return Natural is
        (Files_Suite.Interaction_Support.Display_Position_Of (Model, Settings, Name));
   begin
      Files_Suite.Support.Disk.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      declare
         Names : constant String := "abcdef";
      begin
         for I in Names'Range loop
            Files_Suite.Support.Disk.Write_File (Files_Suite.Support.Disk.Join (Dir, Names (I) & ".txt"));
         end loop;
      end;
      Model := Loaded_Model (Dir);
      Files.Model.Set_View_Mode (Model, Files.Preference_Types.Small_Icons);
      declare
         Action : constant Files.Input_Actions.Input_Action :=
           (Kind    => Files.Input_Actions.Command_Input_Action,
            Command => Files.Commands.Sort_By_Name_Command);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Files.Model.Sort_Is_Ascending (Model), "sort toggled to descending");
      --  Reload the directory while descending is active -- the common browsing
      --  case. The loaded item order must be re-sorted to match the display, or
      --  arrow navigation walks the raw load order and moves the wrong way.
      declare
         Reload : constant Files.Operation_Results.Operation_Result := Files.Operations.Refresh (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal
           (Reload.Status, Files.Operation_Results.Operation_Success, "the descending directory reloads");
      end;
      --  Two-column grid: Down should move down a row (two display positions).
      Files.Model.Selection.Set_Grid_Columns (Model, 2);
      Files_Suite.Support.Models.Select_Name (Model, "c.txt");
      declare
         Start_Pos : constant Natural := Display_Position_Of ("c.txt");
      begin
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Down, Guikit.Input.No_Modifiers, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selection.Selected_Name (Model)),
            Start_Pos + 2,
            "grid Down moves down a row (not up) under descending sort");
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Up, Guikit.Input.No_Modifiers, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selection.Selected_Name (Model)),
            Start_Pos,
            "grid Up returns to the previous row under descending sort");
      end;
   end Test_Descending_Grid_Arrows_Follow_Display;
