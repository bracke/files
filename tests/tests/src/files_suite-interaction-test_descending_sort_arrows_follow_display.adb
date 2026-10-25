separate (Files_Suite.Interaction)
   --  Bug 15 regression: arrow navigation must always move to the visually
   --  adjacent item as displayed, regardless of sort direction. Drives the real
   --  path (sort command through Apply_Input_Action, arrows through Handle_Key)
   --  and uses Build_Snapshot -- the display-order oracle -- to locate items.
   procedure Test_Descending_Sort_Arrows_Follow_Display
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "nav-desc");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Result   : Files.Interaction.Interaction_Result;

      --  Position of Name in the DISPLAYED order (1-based), or 0 when absent.
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
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "a.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "b.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "c.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "d.txt"));
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "e.txt"));
      Model := Loaded_Model (Dir);
      Files.Model.Set_View_Mode (Model, Files.Types.Details);

      --  Toggle to descending name sort through the real command path.
      declare
         Action : constant Files.Events.Input_Action :=
           (Kind    => Files.Events.Command_Input_Action,
            Command => Files.Commands.Sort_By_Name_Command,
            others  => <>);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert (not Files.Model.Sort_Is_Ascending (Model), "the sort command toggles to descending order");

      --  Anchor on a middle item and remember where it sits when displayed.
      Files_Suite.Support.Select_Name (Model, "c.txt");
      declare
         Start_Pos : constant Natural := Display_Position_Of ("c.txt");
      begin
         Assert
           (Start_Pos > 1 and then Start_Pos < 5,
            "the anchor item sits in the middle of the displayed order");

         --  Down must advance to the NEXT displayed item, never the previous one.
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Down, Guikit.Input.No_Modifiers, Base_Font, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selected_Name (Model)),
            Start_Pos + 1,
            "Down moves to the next displayed item under descending sort");

         --  Up must return to the anchor (the previous displayed item).
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Up, Guikit.Input.No_Modifiers, Base_Font, Result);
         Files_Suite.Support.Assert_Equal
           (Display_Position_Of (Files.Model.Selected_Name (Model)),
            Start_Pos,
            "Up moves to the previous displayed item under descending sort");
      end;
   end Test_Descending_Sort_Arrows_Follow_Display;
