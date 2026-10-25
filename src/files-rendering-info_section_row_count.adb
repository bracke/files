separate (Files.Rendering)
   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      --  The selected item's name is rendered once as a heading followed by a
      --  breathing row before the metadata sections.
      Rows : Natural := 2;
   begin
      --  Walk the same ordered section list the renderer draws. Permissions
      --  render as a matrix of fixed height; every other section is a label
      --  row, its wrapped value, and a gap row.
      for Field in Info_Section_Field loop
         if Info_Field_Shown (Info, Field) then
            Rows :=
              Saturating_Add
                (Rows,
                 (if Field = Info_Permissions
                  then Permission_Grid_Rows
                  else Saturating_Add
                         (2,
                          Wrapped_Line_Count (Info_Field_Display_Value (Info, Field), Text_W, Line_Height))));
         end if;
      end loop;

      return Rows;
   end Info_Section_Row_Count;
