separate (Files.Rendering)
   function Info_Section_Row_Count
     (Info        : Info_Snapshot;
      Text_W      : Natural;
      Line_Height : Positive)
      return Natural
   is
      Rows : Natural := 0;
   begin
      --  Field 0 (Name) is omitted: the name rides on every value as a suffix.
      --  Field 2 (Filesize) is omitted for folders: they carry no byte size and
      --  show Contents instead. Field 5 (Permissions) is drawn as the matrix
      --  below, not as text. Field 7 (Kind) is omitted: it duplicates Filetype.
      --  Field 6 (Metadata Error) only appears when metadata actually failed.
      for Field in 1 .. 8 loop
         if Field /= 5
           and then Field /= 7
           and then not (Field = 2 and then Info.Is_Directory)
           and then not (Field = 6 and then not Info.Metadata_Error)
         then
            Rows :=
              Saturating_Add
                (Rows,
                 Saturating_Add
                    (2,
                    Wrapped_Line_Count (Info_Field_Postfixed_Value (Info, Field), Text_W, Line_Height)));
         end if;
      end loop;

      --  Permissions render as a matrix whenever the item's mode was read.
      if Info.Mode_Available then
         Rows := Saturating_Add (Rows, Permission_Grid_Rows);
      end if;

      --  Owner/Group stay bare: they are interactive (inline editing + caret).
      if Info.Ownership_Available then
         for Field in 9 .. 10 loop
            Rows :=
              Saturating_Add
                (Rows,
                 Saturating_Add
                   (2,
                    Wrapped_Line_Count (Info_Field_Display_Value (Info, Field), Text_W, Line_Height)));
         end loop;
      end if;

      if Info.Is_Directory and then Info.Folder_Size_Available then
         Rows :=
           Saturating_Add
             (Rows,
              Saturating_Add
                (2, Wrapped_Line_Count
                      (Folder_Contents_Text (Info) & Info_Postfix (Info), Text_W, Line_Height)));
      end if;

      return Rows;
   end Info_Section_Row_Count;
