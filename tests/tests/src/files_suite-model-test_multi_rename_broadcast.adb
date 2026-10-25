separate (Files_Suite.Model)
   procedure Test_Multi_Rename_Broadcast (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model : Files.Model.Window_Model := Sample_Model;

      function RValue (Visible_Index : Positive) return String is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return To_String (Value);
      end RValue;

      function RCursor (Visible_Index : Positive) return Natural is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return Cursor;
      end RCursor;

      function RActive (Visible_Index : Positive) return Boolean is
         Active : Boolean;
         Value  : Unbounded_String;
         Cursor : Natural;
      begin
         Files.Model.Rename_State_For_Visible (Model, Visible_Index, Active, Value, Cursor);
         return Active;
      end RActive;

      Changed : Boolean;
   begin
      --  Select Alpha.txt (visible 1) and Beta.txt (visible 2) and enter the
      --  synchronized multi-rename.
      Files.Model.Select_Visible (Model, 1);
      Files.Model.Toggle_Visible_Selection (Model, 2);
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Is_Active (Model), "multi-rename activates for two selected items");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Field_Count (Model),
         2,
         "multi-rename opens one field per selected item");

      Assert (RActive (1) and then RActive (2), "both selected rows carry an active rename field");
      Assert (not RActive (3), "an unselected row carries no rename field");
      Assert (RValue (1) = "Alpha.txt" and then RValue (2) = "Beta.txt", "fields pre-fill each item name");
      Assert (RCursor (1) = 5 and then RCursor (2) = 4, "initial carets sit before each extension");

      --  A typed character inserts at every caret, each caret advancing.
      Changed := Files.Model.Rename_Insert_At_Carets (Model, "X");
      Assert (Changed, "insert reports a change across the fields");
      Assert
        (RValue (1) = "AlphaX.txt" and then RValue (2) = "BetaX.txt",
         "insert broadcasts to every field's caret");
      Assert (RCursor (1) = 6 and then RCursor (2) = 5, "each caret advances past the inserted text");

      --  Backspace deletes at every caret.
      Changed := Files.Model.Rename_Delete_Backward (Model);
      Assert (Changed, "backspace reports a change across the fields");
      Assert
        (RValue (1) = "Alpha.txt" and then RValue (2) = "Beta.txt",
         "backspace broadcasts to every field's caret");
      Assert (RCursor (1) = 5 and then RCursor (2) = 4, "each caret retreats after backspace");

      --  A per-field click moves only that field's caret.
      Files.Model.Set_Rename_Caret (Model, Visible_Index => 1, Position => 0);
      Files_Suite.Support.Assert_Equal (RCursor (1), 0, "a click moves the clicked field's caret");
      Files_Suite.Support.Assert_Equal (RCursor (2), 4, "a click leaves the other field's caret untouched");

      --  A keyboard arrow moves every caret together.
      Changed := Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right);
      Assert (Changed, "arrow reports a change across the fields");
      Assert (RCursor (1) = 1 and then RCursor (2) = 5, "a keyboard arrow moves every caret together");
   end Test_Multi_Rename_Broadcast;
