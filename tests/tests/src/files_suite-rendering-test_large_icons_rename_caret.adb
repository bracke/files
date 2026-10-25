separate (Files_Suite.Rendering)
   --  Bug 13: in large-icons view the rename edit must span the cell width,
   --  left-aligned on the label line, with the caret contained in the cell's
   --  label region -- not pinned inside a narrow, name-width centered label.
   procedure Test_Large_Icons_Rename_Caret (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Large_Icons);
      Cell     : Item_Layout;
      Found    : Boolean := False;
   begin
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("a-much-longer-renamed-file-name.txt");
         Item.Rename_Cursor := 0;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      Snapshot.Selected_Count := 1;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;

      declare
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, 20);
         Cells  : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Snapshot, Layout, 20);
      begin
         for C of Cells loop
            if C.Visible_Index = 1 then
               Cell := C;
               Found := True;
            end if;
         end loop;
      end;
      Assert (Found, "the renamed large-icons cell is laid out");

      --  With the cursor at the start, the caret must sit at the cell's left
      --  edge (left-aligned edit), not indented to a centered name-width label.
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Rename_Cursor := 0;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      declare
         Frame          : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         CX, CY, CW, CH : Natural;
         Caret_Found    : Boolean;
      begin
         Find_Caret (Frame, CX, CY, CW, CH, Caret_Found);
         Assert (Caret_Found, "the focused large-icons rename draws a caret");
         Assert
           (CX >= Cell.X and then CX + CW <= Cell.X + Cell.Width,
            "the rename caret stays within the cell horizontally");
         Assert
           (CY >= Cell.Text_Y and then CY + CH <= Cell.Y + Cell.Height,
            "the rename caret sits on the label line inside the cell");
         Assert
           (CX <= Cell.X + 20,
            "the large-icons rename edits from the cell's left edge, not a centered label box");
      end;

      --  With the cursor further along, the caret tracks the text rightward,
      --  proving the editable box spans the cell rather than a tiny label.
      declare
         Item : Item_Snapshot := Snapshot.Items.Element (1);
      begin
         Item.Rename_Cursor := 8;
         Snapshot.Items.Replace_Element (1, Item);
      end;
      declare
         Frame          : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
         CX, CY, CW, CH : Natural;
         Caret_Found    : Boolean;
      begin
         Find_Caret (Frame, CX, CY, CW, CH, Caret_Found);
         Assert (Caret_Found, "the rename caret is drawn as the text grows");
         Assert
           (CX > Cell.X + 20,
            "the caret advances rightward with the text across the wide rename field");
         Assert
           (CX + CW <= Cell.X + Cell.Width and then CY + CH <= Cell.Y + Cell.Height,
            "the advanced caret stays contained in the cell's label region");
      end;
   end Test_Large_Icons_Rename_Caret;
