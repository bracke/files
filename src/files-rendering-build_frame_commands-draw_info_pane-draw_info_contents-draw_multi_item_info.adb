separate (Files.Rendering.Build_Frame_Commands.Draw_Info_Pane.Draw_Info_Contents)
   --  Field-major coalesced layout of two or more selected items.
   procedure Draw_Multi_Item_Info is
      Sections : constant Coalesced_Section_Vectors.Vector :=
        Coalesced_Info_Sections (Snapshot);
      Current_Row : Natural := 0;
   begin
      --  Field-major coalesced layout: each section's label once,
      --  then one value row per selected item (see Coalesced_Info_Rows
      --  for the matching row accounting).
      for Section of Sections loop
         Add_Info_Label (Current_Row, To_String (Section.Key));
         Current_Row := Guikit.Layout.Saturating_Add (Current_Row, 1);
         for Value of Section.Values loop
            Add_Info_Wrapped_Value (Current_Row, Value);
            Current_Row :=
              Guikit.Layout.Saturating_Add (Current_Row, Wrapped_Line_Count (Value, Text_W, Line_Height));
         end loop;
         Current_Row := Guikit.Layout.Saturating_Add (Current_Row, 1);
      end loop;

      --  One accessibility node per item, anchored at its value row in
      --  the first rendered section (values start one row below its
      --  label). Advance by that section's per-item wrapped height.
      if not Sections.Is_Empty then
         declare
            First : constant Coalesced_Section := Sections.First_Element;
            Item_Row : Natural := 1;
            Item_Index : Positive := 1;
         begin
            for Info of Snapshot.Selected_Info loop
               declare
                  Y : constant Integer :=
                    Saturating_Integer_Add (Row_Y, Saturating_Multiply (Item_Row, Line_Height));
                  Visible_Y : constant Integer := Integer'Max (Y, Integer (Info_Pane.Y));
                  Description : constant Unbounded_String :=
                    To_Unbounded_String (Info_Description (Info, Full => False));
               begin
                  if Y >= Integer (Info_Pane.Y)
                    and then Y < Integer (Info_Bottom)
                    and then Text_W > 0
                  then
                     Add_Accessibility_Node
                       (Role_List_Item,
                        Info_Pane.X,
                        Natural (Visible_Y),
                        Text_W,
                        Natural'Min
                          (Line_Height, Info_Bottom - Natural (Visible_Y)),
                        Info.Name,
                        Description);
                  end if;
                  Item_Row :=
                    Guikit.Layout.Saturating_Add
                      (Item_Row,
                       Wrapped_Line_Count (First.Values.Element (Item_Index), Text_W, Line_Height));
                  Item_Index := Item_Index + 1;
               end;
            end loop;
         end;
      end if;
   end Draw_Multi_Item_Info;
