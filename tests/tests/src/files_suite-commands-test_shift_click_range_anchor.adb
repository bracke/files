separate (Files_Suite.Commands)
   procedure Test_Shift_Click_Range_Anchor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
      Shift    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Reset_Root;
      Shift (Guikit.Input.Shift_Key) := True;

      --  Nine items whose ascending-by-name order matches their visible index
      --  (01.txt .. 09.txt), so a visible index equals the item's number.
      for N in 1 .. 9 loop
         Items.Append
           (Files.File_System.Make_Item
              (Root,
               "0" & Character'Val (Character'Pos ('0') + N) & ".txt",
               Files.Types.Regular_File_Item,
               "text/plain"));
      end loop;
      Files.Model.Initialize (Model, Root, Items, Root);

      --  Plain-click 3, shift-click 6, then shift-click 9. The anchor must stay
      --  at 3 across both shift-clicks so the range grows to {3..9}; the bug this
      --  guards against reused the moved cursor as the anchor, collapsing the
      --  second shift-click to {6..9}.
      Result := Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 3);
      Result :=
        Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 6, Modifiers => Shift);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         4,
         "the first shift-click selects the 3..6 range");
      Result :=
        Files.Controller.Handle_Item_Click (Model, Settings, Visible_Index => 9, Modifiers => Shift);

      Files_Suite.Support.Assert_Equal

        (Result.Status,

         Files.Controller.Controller_Selection_Moved,

         "a shift-click reports a selection move");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Count (Model),
         7,
         "the second shift-click extends the range from the original anchor, not the moved cursor");
      for Index in 1 .. 9 loop
         Files_Suite.Support.Assert_Equal
           (Files.Model.Is_Selected (Model, Index),
            (Index in 3 .. 9),
            "exactly items 3..9 are selected after the range extension");
      end loop;
   end Test_Shift_Click_Range_Anchor;
