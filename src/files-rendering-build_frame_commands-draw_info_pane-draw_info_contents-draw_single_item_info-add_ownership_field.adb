separate (Files.Rendering.Build_Frame_Commands.Draw_Info_Pane.Draw_Info_Contents.Draw_Single_Item_Info)
   --  Draw an editable owner or group value and register one
   --  click hit region over it. While editing, the value shows
   --  the editor buffer with an underline and a text caret.
   procedure Add_Ownership_Field
     (Field   : Info_Section_Field;
      Editing : Boolean)
   is
      Value      : constant UString := Info_Field_Value (Info, Field);
      Value_Rows : constant Natural := Wrapped_Line_Count (Value, Text_W, Line_Height);
      Value_Row  : Natural;
      Cell_Y     : Integer;
   begin
      Add_Info_Label (Current_Row, Info_Field_Label_Key (Field));
      Current_Row := Guikit.Layout.Saturating_Add (Current_Row, 1);
      Value_Row := Current_Row;
      Add_Info_Wrapped_Value
        (Value_Row, Value, (if Editing then Text_Color else Muted_Text_Color));
      Cell_Y :=
        Saturating_Integer_Add (Row_Y, Saturating_Multiply (Value_Row, Line_Height));
      if Cell_Y >= Integer (Info_Pane.Y)
        and then Cell_Y + Integer (Line_Height) <= Integer (Info_Bottom)
        and then Text_W > 0
      then
         Result.Ownership_Hits.Append
           (Ownership_Hit_Region'
              (Present  => True,
               Is_Group => Field = Info_Group,
               X        => Text_X,
               Y        => Natural (Cell_Y),
               Width    => Text_W,
               Height   => Line_Height));
         if Editing then
            Add_Rect
              (Text_X,
               Guikit.Layout.Saturating_Add (Natural (Cell_Y), Line_Height - 1),
               Text_W,
               1,
               Selection_Color);
            declare
               Char_W  : constant Positive := Guikit.Layout.Caret_Advance_Width (Line_Height);
               Raw     : constant String := To_String (Value);
               Caret_X : constant Natural :=
                 Guikit.Layout.Saturating_Add
                   (Text_X,
                    Saturating_Multiply
                      (Guikit.Utf8.Display_Units_Before
                         (Raw, Snapshot.Text_Cursor_Position),
                       Char_W));
            begin
               --  A 2 px stroke, inset from the row by a
               --  scaled margin above and below.
               Add_Rect
                 (Caret_X,
                  Guikit.Layout.Saturating_Add (Natural (Cell_Y), Guikit.Layout.Scaled (2, Line_Height)),
                  2,
                  (if Line_Height > Guikit.Layout.Scaled (4, Line_Height)
                   then Line_Height - Guikit.Layout.Scaled (4, Line_Height)
                   else Line_Height),
                  Text_Color);
            end;
         end if;
      end if;
      Current_Row := Guikit.Layout.Saturating_Add (Current_Row, Guikit.Layout.Saturating_Add (Value_Rows, 1));
   end Add_Ownership_Field;
