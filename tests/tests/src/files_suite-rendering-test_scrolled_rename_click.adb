separate (Files_Suite.Rendering)
   --  A long name being renamed scrolls so its caret shows; a click must map
   --  onto the scrolled text the field draws. In a multi-rename each field
   --  scrolls by its own caret, not the first field's.
   procedure Test_Scrolled_Rename_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Line_H    : constant Positive := 20;
      Long_Name : constant String :=
        "a-rename-target-whose-name-is-far-too-long-for-the-details-name-column-of-a-thousand-pixel-window-"
        & "so-the-field-has-to-scroll-to-keep-the-caret-in-view-while-typing-at-its-very-end-0123456789.txt";
      Snapshot  : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);

      procedure Set_Rename (Index : Positive; Cursor : Natural) is
         Item : Item_Snapshot := Snapshot.Items.Element (Index);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String (Long_Name);
         Item.Rename_Cursor := Cursor;
         Snapshot.Items.Replace_Element (Index, Item);
      end Set_Rename;
   begin
      Set_Rename (1, Long_Name'Length);
      Set_Rename (2, 0);
      Snapshot.Selected_Count := 2;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;
      --  The model reports the first renaming field's caret as the text cursor.
      Snapshot.Text_Cursor_Position := Long_Name'Length;

      declare
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, Line_H);
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, Line_H);
         Rows   : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Snapshot, Layout, Line_H);
         Char_W : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_H);

         --  The text cursor a click at the left or right edge of visible row
         --  Index's rename field resolves to.
         function Click_Cursor (Index : Positive; At_End : Boolean) return Natural is
            Field_X, Field_W : Natural := 0;
         begin
            for Cell of Rows loop
               if Cell.Visible_Index = Index then
                  Rename_Field_Extent (Cell, Snapshot.View_Mode, True, Field_X, Field_W, Line_H);
                  Assert (Long_Name'Length * Char_W > Field_W, "the sample name is wider than its rename field");
                  declare
                     Action : constant Files.Events.Input_Action :=
                       Files.Events.Translate_Click
                         (Snapshot, Frame,
                          X           => (if At_End then Field_X + Field_W - 1 else Field_X),
                          Y           => Cell.Y + Cell.Height / 2,
                          Width       => 1000,
                          Height      => 800,
                          Line_Height => Line_H);
                  begin
                     Files_Suite.Support.Assert_Equal
                       (Action.Kind, Files.Events.Text_Click_Input_Action,
                        "a click in a rename field is a text click");
                     Files_Suite.Support.Assert_Equal
                       (Action.Field_Item, Index, "the click carries the clicked row index");
                     return Action.Cursor_Position;
                  end;
               end if;
            end loop;
            Assert (False, "the renaming row is laid out");
            return 0;
         end Click_Cursor;

         Skipped : Natural;
      begin
         --  The scrolled field: its right edge shows the end of the name, so a
         --  click there puts the cursor at the end; its left edge shows the
         --  first column that scrolled in, not the start of the name.
         Files_Suite.Support.Assert_Equal
           (Click_Cursor (1, At_End => True), Long_Name'Length,
            "a click at the end of a scrolled rename field puts the cursor at the end");
         Skipped := Click_Cursor (1, At_End => False);
         Assert (Skipped > 0, "a click at the left edge of a scrolled field lands past the scrolled-off text");

         --  The second field's caret is at its start, so it does not scroll,
         --  although the snapshot's text cursor (the first field's) would.
         Files_Suite.Support.Assert_Equal
           (Click_Cursor (2, At_End => False), 0,
            "each rename field of a multi-rename scrolls by its own caret");
      end;
   end Test_Scrolled_Rename_Click;
