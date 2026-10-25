separate (Files_Suite.Model)
   procedure Test_Type_Ahead_Selection (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Six-item projection with several names sharing a "d" prefix so the
      --  refine and repeated-letter cycling behaviours are observable.
      function Grid_Items return Files.File_System.Item_Vectors.Vector is
         Items : Files.File_System.Item_Vectors.Vector;
      begin
         Items.Append (Files.File_System.Make_Item (Root, "delta", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "Doc", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "dune", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "date", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append (Files.File_System.Make_Item (Root, "eagle", Files.Types.Regular_File_Item, "text/plain"));
         return Items;
      end Grid_Items;

      function New_Grid_Model return Files.Model.Window_Model is
         Model : Files.Model.Window_Model;
      begin
         Files.Model.Initialize
           (Model,
            Directory_Path    => Root,
            Items             => Grid_Items,
            Home_Path         => "/home/test",
            Default_View_Mode => Files.Types.Small_Icons);
         return Model;
      end New_Grid_Model;

      Model    : Files.Model.Window_Model := New_Grid_Model;
      Result   : Files.Controller.Controller_Result;

      procedure Feed (Text : String) is
      begin
         Result := Files.Controller.Append_Focused_Text (Model, Text);
      end Feed;
   begin
      --  Pure matcher: first item starting with the prefix, case-insensitive.
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "do", 1),
         2,
         "matcher returns the first item starting with the prefix");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "DO", 1),
         2,
         "matcher is case-insensitive");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "z", 1),
         0,
         "matcher returns zero when nothing matches");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "", 1),
         0,
         "matcher returns zero for an empty prefix");
      --  Start-index respected: "d" items sit at 1, 3, 4; scanning from 3 finds 3.
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 3),
         3,
         "matcher honours the start index inclusively");
      Files_Suite.Support.Assert_Equal
        (Files.Type_Ahead.Type_Ahead_Target (Grid_Items, "d", 5),
         1,
         "matcher wraps around past the end of the projection");

      --  Through the seam with the grid focused (Focus_None): a bare printable
      --  character selects the first matching item.
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "fresh grid model starts unfocused");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Controller.Controller_Selection_Moved,
         "type-ahead reports a moved selection");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "typing d selects the first d-item (delta)");

      --  A longer prefix refines to the matching item.
      Feed ("u");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "refining to du selects dune");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "du",
         "buffer accumulates the refined prefix");

      --  A non-matching character leaves the selection where it was.
      Feed ("z");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "a non-matching character keeps the current selection");

      --  Repeated single letter cycles through every item starting with it.
      Model := New_Grid_Model;
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "first d selects delta");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 2, "second d cycles to Doc");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "third d cycles to dune");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 4, "fourth d cycles to date");
      Feed ("d");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 1, "fifth d wraps back to delta");

      --  Reset trigger (arrow key): a fresh keystroke starts a new prefix rather
      --  than extending the stale one.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 3, "du selects dune before the reset");
      Files.Model.Move_Selection (Model, Guikit.Input.Move_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "",
         "an arrow key clears the type-ahead buffer");
      Files_Suite.Support.Assert_Equal (Files.Model.Selected_Index (Model), 4, "arrow key moves selection to date");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         1,
         "a keystroke after the reset starts a fresh single-letter cycle (delta)");

      --  Reset trigger (focus change): focusing a text field clears the buffer,
      --  and returning to the grid begins a fresh prefix.
      Model := New_Grid_Model;
      Feed ("d");
      Feed ("u");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Index (Model),
         3,
         "du selects dune before the focus change");
      Files.Model.Focus_Path_Input (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "",
         "focusing a text field clears the type-ahead buffer");

      --  Typing into the focused text field edits the field and never moves the
      --  grid selection (the path input, unlike the filter, does not reproject).
      declare
         Before        : constant Natural := Files.Model.Selected_Index (Model);
         Before_Length : constant Natural := Files.Model.Path_Input_Text (Model)'Length;
      begin
         Feed ("x");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Path_Input_Text (Model)'Length,
            Before_Length + 1,
            "typed text lands in the focused path input");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Type_Ahead_Buffer (Model),
            "",
            "typing into a text field never feeds type-ahead");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Index (Model),
            Before,
            "typing into a text field does not jump the grid selection");
      end;

      --  Back on the grid, a fresh keystroke starts a new prefix.
      Files.Model.Cancel_Focus_Or_Edit (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model),
         Files.Types.Focus_None,
         "cancelling returns focus to the grid");
      Feed ("d");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Type_Ahead_Buffer (Model),
         "d",
         "a keystroke after the focus reset starts a fresh prefix");
   end Test_Type_Ahead_Selection;
