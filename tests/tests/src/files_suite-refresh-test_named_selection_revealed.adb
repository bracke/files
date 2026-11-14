separate (Files_Suite.Refresh)
   --  The window scrolled the selection into view only after a key moved
   --  it. A selection set by name -- a reload that names its item (a new or
   --  renamed one), Open Containing Folder -- stayed wherever it was, often
   --  out of view. Such a selection is now marked, and the window reveals it
   --  after the step that set it with the same scroll a key gets.
   procedure Test_Named_Selection_Revealed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Items    : Files.Items.Item_Vectors.Vector;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      Selected : Boolean;
      pragma Unreferenced (Step);
   begin
      Reset_Root;
      for Index in 1 .. 60 loop
         Items.Append
           (Files.File_System.Make_Item (Root, "f" & Index'Image, Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Assert (not Files.Model.Reveal_Is_Pending (Model), "a new view has nothing to reveal");
      Files.Model.Selection.Select_Visible (Model, 2);
      Assert (not Files.Model.Reveal_Is_Pending (Model), "a click's selection is where the user pointed");
      Selected := Files.Model.Selection.Select_By_Name (Model, "f 55");
      Assert (Selected and then Files.Model.Reveal_Is_Pending (Model), "a selection by name waits to be revealed");
      declare
         Snapshot : Files.Rendering.View_Snapshot := Files.Rendering.Build_Snapshot (Model);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Width => 1000, Height => 600, Line_Height => 20);
         Lines    : constant Natural :=
           Files.Rendering.Scroll_Lines_Revealing (Snapshot, Layout, 20, Files.Model.Selection.Selected_Index (Model));
      begin
         Assert (Lines > 0, "revealing the far item scrolls the view");
         Files.Model.Set_Main_View_Scroll_Lines (Model, Lines);
         Files.Model.Clear_Reveal (Model);
         Snapshot.Main_View_Scroll_Lines := Lines;
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Scroll_Lines_Revealing (Snapshot, Layout, 20, Files.Model.Selection.Selected_Index (Model)),
            Lines, "once revealed the item is in view");
      end;
      Assert (not Files.Model.Reveal_Is_Pending (Model), "a revealed selection waits no more");
      Selected := Files.Model.Selection.Select_By_Name (Model, "missing");
      Assert (not Selected and then not Files.Model.Reveal_Is_Pending (Model), "a name not found reveals nothing");

      --  A reload that names its item.
      for Index in 1 .. 60 loop
         Write_Binary_File (Join (Root, "f" & Index'Image), "x");
      end loop;
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Clear_Reveal (Model);
      Write_Binary_File (Join (Root, "z new"), "new");
      Step := Files.Refresh_Jobs.Start (Model, Settings, Force => True, Select_Name => "z new");
      Await_View (Model, Settings);
      Assert
        (To_String (Files.Model.Selection.Selected_Item (Model).Name) = "z new",
         "the reload selects the item it names");
      Assert (Files.Model.Reveal_Is_Pending (Model), "and asks the window to reveal it");
      Reset_Root;
   end Test_Named_Selection_Revealed;
