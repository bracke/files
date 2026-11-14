separate (Files.Rendering.Build_Frame_Commands.Draw_Info_Pane.Draw_Info_Contents)
   --  One selected item: its name as a heading, then each shown field.
   procedure Draw_Single_Item_Info (Info : Info_Snapshot) is
      Current_Row : Natural := 0;

      procedure Add_Info_Heading is
         Y : constant Integer :=
           Saturating_Integer_Add
             (Row_Y, Saturating_Multiply (Current_Row, Line_Height));
      begin
         Add_Info_Text (Current_Row, Info.Name, Text_Color, Fit => True);
         if Text_W > 1
           and then Y >= Integer (Info_Pane.Y)
           and then Y < Integer (Info_Bottom)
         then
            Add_Text
              (Guikit.Layout.Saturating_Add (Text_X, 1),
               Natural (Y),
               Text_W - 1,
               Natural'Min (Line_Height, Info_Bottom - Natural (Y)),
               Info.Name,
               Text_Color,
               Fit => True);
         end if;
         Current_Row := Guikit.Layout.Saturating_Add (Current_Row, 2);
      end Add_Info_Heading;

      procedure Add_Info_Field
        (Field : Info_Section_Field;
         Color : Render_Color := Text_Color)
      is
         Display_Value : constant UString := Info_Field_Display_Value (Info, Field);
         Value_Rows : constant Natural := Wrapped_Line_Count (Display_Value, Text_W, Line_Height);
      begin
         Add_Info_Label (Current_Row, Info_Field_Label_Key (Field));
         Current_Row := Guikit.Layout.Saturating_Add (Current_Row, 1);
         Add_Info_Wrapped_Value (Current_Row, Display_Value, Color);
         Current_Row := Guikit.Layout.Saturating_Add (Current_Row, Guikit.Layout.Saturating_Add (Value_Rows, 1));
      end Add_Info_Field;

      procedure Add_Permission_Grid is separate;

      procedure Add_Ownership_Field
        (Field   : Info_Section_Field;
         Editing : Boolean) is separate;
   begin
      Add_Info_Heading;
      --  One ordered section list (Info_Section_Field) drives both
      --  this drawing and Info_Section_Row_Count. Permissions render
      --  as a labelled matrix (no text summary), clickable only when
      --  editable (gated inside Add_Permission_Grid); owner and
      --  group are inline-editable values.
      for Field in Info_Section_Field loop
         if Info_Field_Shown (Info, Field) then
            case Field is
               when Info_Permissions =>
                  Add_Permission_Grid;
               when Info_Owner =>
                  Add_Ownership_Field (Field, Info.Owner_Editing);
               when Info_Group =>
                  Add_Ownership_Field (Field, Info.Group_Editing);
               when others =>
                  Add_Info_Field (Field);
            end case;
         end if;
      end loop;
      declare
         Section_H : constant Natural :=
           Natural'Min
             (Saturating_Multiply
                (Line_Height,
                 Info_Section_Row_Count (Info, Text_W, Line_Height)),
              Info_Pane.Height);
         Visible_Y : constant Integer := Integer'Max (Row_Y, Integer (Info_Pane.Y));
         Raw_Bottom : constant Integer :=
           Integer'Min
             (Saturating_Integer_Add (Row_Y, Section_H),
              Integer (Info_Bottom));
         Visible_H : constant Natural :=
           (if Raw_Bottom > Visible_Y then Natural (Raw_Bottom - Visible_Y) else 0);
         Description : constant Unbounded_String :=
           To_Unbounded_String (Info_Description (Info, Full => True));
      begin
         if Visible_H > 0 and then Text_W > 0 then
            Add_Accessibility_Node
              (Role_List_Item,
               Info_Pane.X,
               Natural (Visible_Y),
               Text_W,
               Visible_H,
               Info.Name,
               Description);
         end if;
      end;
   end Draw_Single_Item_Info;
