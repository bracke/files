separate (Files_Suite.Rendering)
   --  A synchronized multi-rename must draw one field and one caret per renaming
   --  row, each caret at that row's own cursor.
   procedure Test_Multi_Rename_Fields_And_Carets (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Carets   : Natural := 0;
      First_X  : Natural := 0;
      Second_X : Natural := 0;

      procedure Set_Rename (Index : Positive; Cursor : Natural) is
         Item : Item_Snapshot := Snapshot.Items.Element (Index);
      begin
         Item.Selected := True;
         Item.Renaming := True;
         Item.Rename_Value := To_Unbounded_String ("abcdef");
         Item.Rename_Cursor := Cursor;
         Snapshot.Items.Replace_Element (Index, Item);
      end Set_Rename;
   begin
      Set_Rename (1, 1);
      Set_Rename (2, 4);
      Snapshot.Selected_Count := 2;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;

      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, 20);
      begin
         for Rect of Frame.Rectangles loop
            if Rect.Width in 1 .. 2 and then Rect.Color = Text_Color then
               Carets := Carets + 1;
               if First_X = 0 then
                  First_X := Rect.X;
               else
                  Second_X := Rect.X;
               end if;
            end if;
         end loop;
      end;

      Files_Suite.Support.Assert_Equal

        (Carets,

         2,

         "two renaming rows draw exactly two carets");
      --  The two rows share the same text but differ by three cursor cells, so
      --  their carets sit three advance-widths apart.
      Files_Suite.Support.Assert_Equal
        (Natural'Max (First_X, Second_X) - Natural'Min (First_X, Second_X),
         3 * Guikit.Layout.Caret_Advance_Width (20),
         "each row's caret tracks that row's own cursor position");
   end Test_Multi_Rename_Fields_And_Carets;
