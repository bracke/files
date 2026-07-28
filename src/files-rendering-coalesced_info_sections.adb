separate (Files.Rendering)
   function Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector
   is
      Sections : Coalesced_Section_Vectors.Vector;

      --  Collect the value of Field across every selected item, using the
      --  display form for the wrapped extra field (8).
      function Field_Values (Field : Natural) return Info_Value_Vectors.Vector is
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if Field = 8 then
               Values.Append (Info_Field_Display_Value (Info, Field));
            else
               Values.Append (Info_Field_Value (Info, Field));
            end if;
         end loop;
         return Values;
      end Field_Values;

      --  Postfix each per-item value with " (<name>)" so a coalesced row shows
      --  which selected item it describes. Values are one-per-item in the same
      --  order as Selected_Info. The Name section is left bare (it is the roster).
      function Qualified (Values : Info_Value_Vectors.Vector) return Info_Value_Vectors.Vector is
         Result : Info_Value_Vectors.Vector;
         Index  : Positive := 1;
      begin
         for Info of Snapshot.Selected_Info loop
            Result.Append (Values.Element (Index) & " (" & Info.Name & ")");
            Index := Index + 1;
         end loop;
         return Result;
      end Qualified;

      procedure Add_Field_Section (Key : String; Field : Natural) is
      begin
         Sections.Append
           (Coalesced_Section'
              (Key    => To_Unbounded_String (Key),
               Values => Qualified (Field_Values (Field))));
      end Add_Field_Section;

      Any_Directory : Boolean := False;
      Any_Ownership : Boolean := False;
      Any_Error     : Boolean := False;
   begin
      for Info of Snapshot.Selected_Info loop
         Any_Directory := Any_Directory or else Info.Is_Directory;
         Any_Ownership := Any_Ownership or else Info.Ownership_Available;
         Any_Error     := Any_Error or else Info.Metadata_Error;
      end loop;

      --  No dedicated Name section: every value below is postfixed with the item
      --  name, which serves as the per-row identifier.
      Add_Field_Section ("info.filetype", 1);

      --  Filesize applies only to files: a folder carries no byte size, so it
      --  contributes no row. When every selected item is a folder the section is
      --  omitted entirely (folders show Contents instead).
      declare
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if not Info.Is_Directory then
               Values.Append (Info_Field_Value (Info, 2) & Info_Postfix (Info));
            end if;
         end loop;
         if not Values.Is_Empty then
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.size"), Values => Values));
         end if;
      end;

      if Any_Directory then
         declare
            Values : Info_Value_Vectors.Vector;
            Rows   : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Is_Directory and then Info.Folder_Size_Available then
                  Values.Append (Folder_Contents_Text (Info));
               else
                  Values.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Rows := Qualified (Values);
            --  The combined selection total is the section's last line (not tied
            --  to any one item, so it carries no name postfix).
            Rows.Append
              (To_Unbounded_String
                 (Files.Localization.Text ("info.contents.total") & ": "
                  & Size_Text (Snapshot.Selection_Total_Bytes)
                  & (if Snapshot.Selection_Total_Pending then " ..." else "")));
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.folder_size"), Values => Rows));
         end;
      end if;

      Add_Field_Section ("info.created", 3);
      Add_Field_Section ("info.modified", 4);

      --  Permissions inline (readable, writable, ... on one line) so each item
      --  occupies a single coalesced row rather than one row per permission.
      declare
         Values : Info_Value_Vectors.Vector;
      begin
         for Info of Snapshot.Selected_Info loop
            if Length (Info.Permissions) = 0 then
               Values.Append (To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
            else
               Values.Append
                 (To_Unbounded_String (Permission_Text (To_String (Info.Permissions), Inline => True)));
            end if;
         end loop;
         Sections.Append
           (Coalesced_Section'(Key => To_Unbounded_String ("info.permissions"), Values => Qualified (Values)));
      end;

      if Any_Ownership then
         declare
            Owners : Info_Value_Vectors.Vector;
            Groups : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Ownership_Available then
                  Owners.Append (Info_Field_Value (Info, 9));
                  Groups.Append (Info_Field_Value (Info, 10));
               else
                  Owners.Append (To_Unbounded_String (Coalesced_Placeholder));
                  Groups.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.owner"), Values => Qualified (Owners)));
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.group"), Values => Qualified (Groups)));
         end;
      end if;

      --  Kind (field 7) is omitted: it duplicates the Filetype section.
      Add_Field_Section ("info.extra", 8);

      if Any_Error then
         declare
            Values : Info_Value_Vectors.Vector;
         begin
            for Info of Snapshot.Selected_Info loop
               if Info.Metadata_Error then
                  Values.Append (Info_Field_Value (Info, 6));
               else
                  Values.Append (To_Unbounded_String (Coalesced_Placeholder));
               end if;
            end loop;
            Sections.Append
              (Coalesced_Section'(Key => To_Unbounded_String ("info.metadata_error"), Values => Qualified (Values)));
         end;
      end if;

      return Sections;
   end Coalesced_Info_Sections;
