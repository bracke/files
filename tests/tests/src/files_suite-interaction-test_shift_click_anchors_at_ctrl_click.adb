separate (Files_Suite.Interaction)
   --  The range anchor is the item the last plain or Ctrl click chose, not an
   --  end of the selection: click 3, Ctrl-click 7, Shift-click 10 selects
   --  7 .. 10 (a shift-click replaces the selection with the range), and a
   --  further Shift-click 5 ranges from 7 again.
   procedure Test_Shift_Click_Anchors_At_Ctrl_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Items    : Files.Items.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;

      procedure Click_Item (Index : Positive; Modifiers : Guikit.Input.Modifier_Set) is
         X, Y  : Natural;
         Found : Boolean;
      begin
         Item_Center (Model, Index, X, Y, Found);
         Assert (Found, "a layout cell exists for item" & Index'Image);
         Click (Model, Settings, X, Y, Modifiers, Result);
      end Click_Item;

      procedure Expect_Selected (First, Last : Positive; Message : String) is
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            Assert (Files.Model.Is_Selected (Model, Index) = (Index in First .. Last),
                    Message & ": item" & Index'Image);
         end loop;
      end Expect_Selected;
   begin
      for Index in 1 .. 12 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Character'Val (Character'Pos ('a') + Index - 1),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      Click_Item (3, Guikit.Input.No_Modifiers);
      Click_Item (7, Ctrl);
      Assert (Files.Model.Is_Selected (Model, 3) and then Files.Model.Is_Selected (Model, 7),
              "a ctrl-click adds to the selection");
      Click_Item (10, Shift);
      Expect_Selected (7, 10, "shift-click ranges from the ctrl-clicked item");
      Click_Item (5, Shift);
      Expect_Selected (5, 7, "a second shift-click keeps the anchor");
   end Test_Shift_Click_Anchors_At_Ctrl_Click;
