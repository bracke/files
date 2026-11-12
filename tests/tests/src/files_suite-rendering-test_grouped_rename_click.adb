separate (Files_Suite.Rendering)
   --  With grouping on, the rows hold group headers between the items, so an
   --  item's visible index is not its row position: a click in the rename
   --  field of an item below a header must still land in that field, not end
   --  the rename by hitting the row the visible index names as a position.
   procedure Test_Grouped_Rename_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Line_H    : constant Positive := 20;
      Long_Name : constant String :=
        "a-rename-target-whose-name-is-far-too-long-for-the-details-name-column-of-a-thousand-pixel-window-"
        & "so-the-field-has-to-scroll-to-keep-the-caret-in-view-while-typing-at-its-very-end-0123456789.txt";
      Snapshot  : View_Snapshot := Sample_Snapshot (4, Files.Types.Details);
      Header    : constant Item_Snapshot :=
        (Is_Group_Header => True,
         Group_Label     => To_Unbounded_String ("band"),
         Visible_Index   => 0,
         others          => <>);
      Renamed   : constant Positive := 3;
   begin
      for Index in Snapshot.Items.First_Index .. Snapshot.Items.Last_Index loop
         if Snapshot.Items (Index).Visible_Index = Renamed then
            declare
               Item : Item_Snapshot := Snapshot.Items.Element (Index);
            begin
               Item.Selected := True;
               Item.Renaming := True;
               Item.Rename_Value := To_Unbounded_String (Long_Name);
               Item.Rename_Cursor := Long_Name'Length;
               Snapshot.Items.Replace_Element (Index, Item);
            end;
         end if;
      end loop;
      --  Bands before items 1 and 3: rows are header, 1, 2, header, 3, 4.
      Snapshot.Items.Insert (Snapshot.Items.First_Index + 2, Header);
      Snapshot.Items.Insert (Snapshot.Items.First_Index, Header);
      Snapshot.Group_By := Files.Types.Group_By_Type;
      Snapshot.Selected_Count := 1;
      Snapshot.Rename_Active := True;
      Snapshot.Focus := Files.Types.Focus_Rename_Input;
      Snapshot.Text_Cursor_Position := Long_Name'Length;
      Files_Suite.Support.Assert_Equal
        (Row_Position_Of (Snapshot, Renamed), Renamed + 2, "the renamed item sits two header rows further down");
      Files_Suite.Support.Assert_Equal (Row_Position_Of (Snapshot, 1), 2, "the first item follows its header");
      Files_Suite.Support.Assert_Equal (Row_Position_Of (Snapshot, 9), 0, "an absent visible index has no row");

      declare
         Frame  : constant Frame_Commands := Build_Frame_Commands (Snapshot, 1000, 800, Line_H);
         Layout : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snapshot, 1000, 800, Line_H);
         Rows   : constant Item_Layout_Vectors.Vector := Calculate_Item_Layout (Snapshot, Layout, Line_H);
         Found  : Boolean := False;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = Renamed then
               Found := True;
               declare
                  Field_X, Field_W : Natural := 0;
               begin
                  Rename_Field_Extent (Cell, Snapshot.View_Mode, True, Field_X, Field_W, Line_H);
                  declare
                     Action : constant Files.Events.Input_Action :=
                       Files.Events.Translate_Click
                         (Snapshot, Frame,
                          X           => Field_X + Field_W - 1,
                          Y           => Cell.Y + Cell.Height / 2,
                          Width       => 1000,
                          Height      => 800,
                          Line_Height => Line_H);
                  begin
                     Files_Suite.Support.Assert_Equal
                       (Action.Kind, Files.Events.Text_Click_Input_Action,
                        "a click in a grouped row's rename field is a text click");
                     Files_Suite.Support.Assert_Equal
                       (Action.Field_Item, Renamed, "the click carries the clicked item's visible index");
                     Files_Suite.Support.Assert_Equal
                       (Action.Cursor_Position, Long_Name'Length,
                        "the click maps onto the renamed item's own scrolled text");
                  end;
               end;
            end if;
         end loop;
         Assert (Found, "the renaming row is laid out");
      end;
   end Test_Grouped_Rename_Click;
