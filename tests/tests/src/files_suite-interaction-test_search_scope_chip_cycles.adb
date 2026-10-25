separate (Files_Suite.Interaction)
   procedure Test_Search_Scope_Chip_Cycles (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "scope-chip");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Result   : Files.Interaction.Interaction_Result;
      Toolbar  : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Window_W);
      Chip     : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of (Toolbar, Line);
      Chip_X   : constant Natural := Chip.X + Chip.Width / 2;
      Chip_Y   : constant Natural := Chip.Y + Chip.Height / 2;
      Full_Count : Natural;

      function Chip_Action (Model : Files.Model.Window_Model) return Files.Events.Input_Action is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
      begin
         return Files.Events.Translate_Click
           (Snapshot, Frame, Chip_X, Chip_Y, Window_W, Window_H, Line_Height => Line);
      end Chip_Action;
   begin
      Assert (Chip.Visible, "the scope chip fits and is laid out at the default window width");

      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      --  One file matches by NAME only, one by CONTENT only, so the two search
      --  scopes return visibly different result sets from the same query text.
      Files_Suite.Support.Write_File
        (Files_Suite.Support.Join (Dir, "needle-name.txt"), "irrelevant body");
      Files_Suite.Support.Write_File
        (Files_Suite.Support.Join (Dir, "plain.txt"), "has a needle inside the body");
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Files_Suite.Support.Root);
      Full_Count := Files.Model.Item_Count (Model);
      Files.Model.Set_Filter (Model, "needle");

      --  The frame draws the chip: an accessibility node advertises it.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Window_W, Window_H, Line);
         Found    : Boolean := False;
      begin
         Assert
           (Snapshot.Search_Scope = Files.Types.Filter_Here,
            "the snapshot starts on the Filter_Here scope for the renderer to draw");
         for Node of Frame.Accessibility loop
            if Ada.Strings.Unbounded.To_String (Node.Name) =
              Files.Localization.Text ("accessibility.search_scope")
            then
               Found := True;
            end if;
         end loop;
         Assert (Found, "the frame draws an accessibility node for the scope chip");
      end;

      --  First chip click: the click resolves to the scope-toggle action rather
      --  than a filter text click, and does not focus the filter input.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Search_Scope_Toggle_Input_Action,
            "clicking the chip yields the scope-toggle action, not a text click");
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Names,
         "the first chip click cycles to the Search_Names scope");
      Assert
        (Files.Model.Focus (Model) /= Files.Types.Focus_Filter_Input,
         "the chip click does not focus the filter input");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "cycling to Search_Names re-runs the query as a recursive name search");

      --  Second chip click: cycle to Search_Contents and re-run as a grep.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Search_Contents,
         "the second chip click cycles to the Search_Contents scope");
      Assert (Files.Model.Search_Results_Are_Active (Model), "content results are shown");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         1,
         "cycling to Search_Contents re-runs the query as a recursive content search");

      --  Third chip click: cycle back to Filter_Here and restore the directory.
      declare
         Action : constant Files.Events.Input_Action := Chip_Action (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Action, Base_Font, Guikit.Input.No_Modifiers, Result);
      end;
      Assert
        (Files.Model.Search_Scope_Of (Model) = Files.Types.Filter_Here,
         "the third chip click cycles back to Filter_Here");
      Assert
        (not Files.Model.Search_Results_Are_Active (Model),
         "returning to Filter_Here drops the search-results state");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Item_Count (Model),
         Full_Count,
         "returning to Filter_Here restores the plain directory listing");
   end Test_Search_Scope_Chip_Cycles;
