with Files.Model.Creation;
with Files.Model.Filtering;
with Files.Preference_Types;
with Files.Rendering.Testing;
with Files.Model.Status_Samples;
with Files.Model.Testing;
with Guikit.Input;
with Files.Snapshot_Policy.Settings_Keys;
with Files_Suite.Support.Models;
separate (Files_Suite.Rendering)
   --  The window keeps a snapshot's rows across a change of the selection
   --  alone (Snapshot_Policy.Patch_Rows). That is right only if every
   --  selection change leaves Rows_Revision where it was, and every other
   --  change a row shows moves it; and the patched snapshot must be the one a
   --  rebuild would give.
   procedure Test_Selection_Patch_Matches_Rebuild (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;

      procedure Check (Step : String; Change : not null access procedure) is
         Before : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Rows   : constant Natural := Files.Model.Rows_Revision (Model);
         Moved  : constant Natural := Files.Model.Revision (Model);
      begin
         Change.all;
         Assert (Files.Model.Revision (Model) /= Moved, Step & ": the model notes the change");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Rows_Revision (Model), Rows, Step & ": the rows revision stays");
         Assert
           (Files.Rendering.Testing.Build_Snapshot_Keeping_Rows (Model, Settings, Before)
            = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Before.Now),
            Step & ": the patched snapshot is the rebuilt one");
      end Check;

      procedure First is begin Files.Model.Selection.Select_Visible (Model, 1); end First;
      procedure Down is begin Files.Model.Selection.Move (Model, Guikit.Input.Move_Down); end Down;
      procedure Toggle is begin Files.Model.Selection.Toggle_Visible_Selection (Model, 3); end Toggle;
      procedure Span is begin Files.Model.Selection.Select_Visible_Range (Model, 1, 2); end Span;
      procedure All_Rows is begin Files.Model.Selection.Select_All_Visible (Model); end All_Rows;
      procedure Invert is begin Files.Model.Selection.Invert (Model); end Invert;
      procedure Clear is begin Files.Model.Selection.Clear (Model); end Clear;
      procedure Last is begin Files.Model.Selection.Select_Last_Visible (Model); end Last;
      procedure By_Name is begin Files_Suite.Support.Models.Select_Name (Model, "Beta.txt"); end By_Name;
   begin
      for Grouped in Boolean loop
         if Grouped then
            Settings.Group_By := Files.Preference_Types.Group_By_Type;
            Files.Model.Set_View_Mode (Model, Files.Preference_Types.Details);
            Files.Model.Sync_Grouping (Model, Settings);
         end if;
         declare
            Mode : constant String := (if Grouped then "grouped " else "");
         begin
            Check (Mode & "select the first", First'Access);
            Check (Mode & "move down", Down'Access);
            Check (Mode & "toggle a row", Toggle'Access);
            Check (Mode & "select a range", Span'Access);
            Check (Mode & "select all", All_Rows'Access);
            Check (Mode & "invert", Invert'Access);
            Check (Mode & "clear", Clear'Access);
            Check (Mode & "select the last", Last'Access);
            Check (Mode & "select by name", By_Name'Access);
         end;
      end loop;

      --  The header-only changes (Touch_Header): what they change is drawn
      --  outside the rows, so the rows a patch keeps must be a rebuild's.
      declare
         procedure Check_Header (Step : String; Change : not null access procedure) is
            Before : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            Rows   : constant Natural := Files.Model.Rows_Revision (Model);
         begin
            Change.all;
            Files_Suite.Support.Assert_Equal
              (Files.Model.Rows_Revision (Model), Rows, Step & ": the rows revision stays");
            Assert
              (Files.Rendering.Testing.Build_Snapshot_Keeping_Rows (Model, Settings, Before)
               = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Before.Now),
               Step & ": the patched snapshot is the rebuilt one");
         end Check_Header;

         Selected : constant String := To_String (Files.Model.Selection.Selected_Item (Model).Full_Path);

         procedure Size is
         begin
            Files.Model.Testing.Set_Folder_Size
              (Model, Selected, (Available => True, Total_Bytes => 4096, File_Count => 2, Item_Count => 3,
                                 Capped => False));
         end Size;
         procedure Unsize is begin Files.Model.Folder_Sizes.Clear (Model); end Unsize;
         procedure Space is
         begin
            Files.Model.Status_Samples.Set_Volume_Space
              (Model, Files.Model.Current_Path (Model), (Known => True, Free_Bytes => 1_000, Total_Bytes => 5_000),
               Ada.Calendar.Clock);
         end Space;
         procedure Type_Ahead is begin Files.Model.Selection.Reset_Type_Ahead (Model); end Type_Ahead;
      begin
         Check_Header ("a folder size measured", Size'Access);
         Check_Header ("folder sizes dropped", Unsize'Access);
         Check_Header ("the free space sampled", Space'Access);
         Check_Header ("type-ahead reset", Type_Ahead'Access);
      end;

      --  A column drag: settings the rows do not read.
      declare
         Before : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Key    : constant Files.Snapshot_Policy.Settings_Keys.Snapshot_Settings_Key :=
           Files.Snapshot_Policy.Settings_Keys.Snapshot_Settings_Key_Of (Settings);
      begin
         Settings.Column_Widths (Files.Preference_Types.Name_Column) := Settings.Column_Widths
           (Files.Preference_Types.Name_Column) + 24;
         Assert
           (Files.Snapshot_Policy.Settings_Keys.Same_Row_Settings (Settings, Key), "a column width is no row setting");
         Assert
           (Files.Rendering.Testing.Build_Snapshot_Keeping_Rows (Model, Settings, Before)
            = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Before.Now),
            "a column drag's patched snapshot is the rebuilt one");
      end;

      --  A selection change during a synchronized multi-rename drops the
      --  field of the row it leaves: the window may keep the rows only if
      --  that left them as a rebuild draws them.
      declare
         Rows : Natural;
      begin
         Files.Model.Selection.Select_Visible (Model, 1);
         Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
         Files.Model.Rename.Toggle (Model);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Testing.Rename_Field_Count (Model), 2, "the multi-rename opens two fields");
         declare
            Before : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
         begin
            Rows := Files.Model.Rows_Revision (Model);
            Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
            Files_Suite.Support.Assert_Equal
              (Files.Model.Testing.Rename_Field_Count (Model), 1, "deselecting a row drops its rename field");
            Assert
              (Files.Model.Rows_Revision (Model) /= Rows
               or else Files.Rendering.Testing.Build_Snapshot_Keeping_Rows (Model, Settings, Before)
                 = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Before.Now),
               "a selection change during a multi-rename keeps the rows only as a rebuild draws them");
         end;
         Files.Model.Rename.Toggle (Model);
      end;

      --  Typing in rename fields and moving their carets leaves the rows
      --  revision: a patch writes the renamed rows again, and must draw what
      --  a rebuild draws. Two fields at once, and the pending create row,
      --  whose name follows its field.
      declare
         procedure Check_Rename (Step : String; Change : not null access procedure) is
            Before : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            Rows   : constant Natural := Files.Model.Rows_Revision (Model);
            Rename : constant Natural := Files.Model.Rename_Revision (Model);
         begin
            Change.all;
            Files_Suite.Support.Assert_Equal
              (Files.Model.Rows_Revision (Model), Rows, Step & ": the rows revision stays");
            Assert (Files.Model.Rename_Revision (Model) /= Rename, Step & ": the rename revision moves");
            Assert
              (Files.Rendering.Testing.Build_Snapshot_Keeping_Rows (Model, Settings, Before)
               = Files.Rendering.Testing.Build_Snapshot_At (Model, Settings, Before.Now),
               Step & ": the patched snapshot is the rebuilt one");
         end Check_Rename;

         Changed : Boolean;
         pragma Unreferenced (Changed);
         procedure Type_Text is begin Changed := Files.Model.Rename.Insert_At_Carets (Model, "xy"); end Type_Text;
         procedure Erase is begin Changed := Files.Model.Rename.Delete (Model, Backward => True); end Erase;
         procedure Left is
         begin
            Changed := Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Left);
         end Left;
         procedure Home is begin Changed := Files.Model.Rename.Set_All_Carets_Home (Model); end Home;
         procedure Caret is begin Files.Model.Rename.Set_Caret (Model, 1, 2); end Caret;
         procedure Replace is begin Files.Model.Rename.Set_Text (Model, "Renamed.txt"); end Replace;
      begin
         Files.Model.Selection.Select_Visible (Model, 1);
         Files.Model.Selection.Toggle_Visible_Selection (Model, 2);
         Files.Model.Rename.Toggle (Model);
         Check_Rename ("rename typing", Type_Text'Access);
         Check_Rename ("rename delete", Erase'Access);
         Check_Rename ("rename caret left", Left'Access);
         Check_Rename ("rename caret home", Home'Access);
         Check_Rename ("rename caret click", Caret'Access);
         Check_Rename ("rename text set", Replace'Access);
         Files.Model.Rename.Toggle (Model);

         Files.Model.Creation.Begin_Create_File (Model, "untitled.txt");
         Check_Rename ("new file name typing", Type_Text'Access);
         Check_Rename ("new file name delete", Erase'Access);
         --  Toggling the rename off cancels the pending create.
         Files.Model.Rename.Toggle (Model);
      end;

      --  And a change a row shows moves it: the filter hides rows.
      declare
         Rows : constant Natural := Files.Model.Rows_Revision (Model);
      begin
         Files.Model.Filtering.Set_Filter (Model, "Gamma");
         Assert (Files.Model.Rows_Revision (Model) /= Rows, "a filter change moves the rows revision");
      end;
   end Test_Selection_Patch_Matches_Rebuild;
