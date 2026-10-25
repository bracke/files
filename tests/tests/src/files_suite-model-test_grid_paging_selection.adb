separate (Files_Suite.Model)
   procedure Test_Grid_Paging_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      function Paging_Model (Count : Natural) return Files.Model.Window_Model is
         Items : Files.File_System.Item_Vectors.Vector;
         Built : Files.Model.Window_Model;
      begin
         for Index in 1 .. Count loop
            Items.Append
              (Files.File_System.Make_Item
                 (Root,
                  "Item" & Ada.Strings.Fixed.Trim (Integer'Image (Index), Ada.Strings.Both) & ".txt",
                  Files.Types.Regular_File_Item,
                  "text/plain"));
         end loop;
         Files.Model.Initialize
           (Built,
            Directory_Path    => Root,
            Items             => Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         return Built;
      end Paging_Model;

      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Paging_Model (25);
      Home_Dir : constant String := Files.Model.Current_Path (Model);
      Result   : Files.Controller.Controller_Result;
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Model.Visible_Count (Model),
         25,
         "paging model exposes all 25 visible items");

      --  Direct model primitives: first / last selection.
      Files.Model.Select_Last_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         25,
         "Select_Last_Visible selects the last visible item");
      Files.Model.Select_First_Visible (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "Select_First_Visible selects the first visible item");

      --  Single-column paging moves by Page_Rows items and clamps at the edges.
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         11,
         "PageDown advances the selection by one page (10 rows)");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         21,
         "a second PageDown advances another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 25, "PageDown clamps at the last item");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => True);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 25, "PageDown on the last item stays put");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         15,
         "PageUp retreats the selection by one page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 5, "a second PageUp retreats another page");
      Files.Model.Move_Selection_By_Page (Model, 10, Down => False);
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "PageUp clamps at the first item");

      --  Grid stride: with 3 columns a page spans Page_Rows * columns items.
      Files.Model.Set_Selection_Grid_Columns (Model, 3);
      Files.Model.Select_First_Visible (Model);
      Files.Model.Move_Selection_By_Page (Model, 2, Down => True);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         7,
         "grid paging moves Page_Rows * columns items (2*3)");

      --  Empty model: paging clears rather than crashing.
      declare
         Empty : Files.Model.Window_Model := Paging_Model (0);
      begin
         Files.Model.Select_First_Visible (Empty);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Empty),
            0,
            "first-visible on an empty grid selects nothing");
         Files.Model.Move_Selection_By_Page (Empty, 10, Down => True);
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Empty),
            0,
            "paging an empty grid selects nothing");
      end;

      --  Through the real controller key seam: plain Home/End move the grid
      --  selection and never navigate (Alt+Home stays the navigate-home key).
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_End);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "plain End moves the grid selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         25,
         "plain End selects the last visible item");
      Files_Suite.Support.Assert_Equal (Files.Model.Current_Path (Model), Home_Dir, "plain End does not navigate");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "plain Home moves the grid selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "plain Home selects the first visible item");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Home_Dir,
         "plain Home does not navigate home (that stays Alt+Home)");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Home);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Ignored,
         "plain Home on the first item is ignored");

      --  Alt+Home remains the navigate-home shortcut, distinct from plain Home.
      Assert
        (Files.Commands.Find_By_Shortcut
           (Guikit.Input.Key_Home, [Guikit.Input.Alt_Key => True, others => False])
           = Files.Commands.Navigate_Home_Command,
         "Alt+Home is still bound to navigate-home");
   end Test_Grid_Paging_Selection;
