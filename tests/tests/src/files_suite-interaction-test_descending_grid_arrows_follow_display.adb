separate (Files_Suite.Interaction)
   procedure Test_Descending_Grid_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "nav-desc-grid");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;

      function Display_Position_Of (Name : String) return Natural is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
      begin
         for Index in 1 .. Natural (Snapshot.Items.Length) loop
            if Ada.Strings.Unbounded.To_String (Snapshot.Items.Element (Index).Name) = Name then
               return Index;
            end if;
         end loop;
         return 0;
      end Display_Position_Of;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      declare
         Names : constant String := "abcdef";
      begin
         for I in Names'Range loop
            Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, Names (I) & ".txt"));
         end loop;
      end;
      Model := Loaded_Model (Dir);
      Files.Model.Set_View_Mode (Model, Files.Types.Small_Icons);
      declare
         Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Name_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Files.Model.Sort_Is_Ascending (Model), "sort toggled to descending");
      --  Reload the directory while descending is active -- the common browsing
      --  case. The loaded item order must be re-sorted to match the display, or
      --  arrow navigation walks the raw load order and moves the wrong way.
      declare
         Reload : constant Files.Operations.Operation_Result := Files.Operations.Refresh (Model, Settings);
      begin
         Files_Suite.Support.Assert_Equal
           (Reload.Status, Files.Operations.Operation_Success, "the descending directory reloads");
      end;
      --  Two-column grid: Down should move down a row (two display positions).
      Files.Model.Set_Selection_Grid_Columns (Model, 2);
      Files_Suite.Support.Select_Name (Model, "c.txt");
      declare
         Start_Pos : constant Natural := Display_Position_Of ("c.txt");
      begin
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Down, Guikit.Input.No_Modifiers, Base_Font, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selected_Name (Model)),
            Start_Pos + 2,
            "grid Down moves down a row (not up) under descending sort");
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Up, Guikit.Input.No_Modifiers, Base_Font, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selected_Name (Model)),
            Start_Pos,
            "grid Up returns to the previous row under descending sort");
      end;
   end Test_Descending_Grid_Arrows_Follow_Display;
