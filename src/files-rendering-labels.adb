with Ada.Strings;
with Files.Localization;

package body Files.Rendering.Labels is

   function Free_Space_Label (Snapshot : View_Snapshot) return String is
   begin
      --  Omitted when free space is unknown or an error line is showing, so the
      --  status area shows no bogus free-space field in those cases.
      if not Snapshot.Free_Space_Known
        or else Length (Snapshot.Last_Error_Key) > 0
      then
         return "";
      end if;

      --  In bar mode the field is a graphical bar, so no text is drawn (falls
      --  through to text when the totals are missing).
      if Free_Space_Bar_Active (Snapshot) then
         return "";
      end if;

      --  In used-space mode, show the difference from total capacity; fall back
      --  to free space when the total is unknown or inconsistent.
      if Snapshot.Show_Used_Space
        and then Snapshot.Total_Space_Bytes > 0
        and then Snapshot.Total_Space_Bytes >= Snapshot.Free_Space_Bytes
      then
         return Files.Localization.Text
           ("status.used_space", "size", Size_Text (Snapshot.Total_Space_Bytes - Snapshot.Free_Space_Bytes));
      end if;

      return Files.Localization.Text ("status.free_space", "size", Size_Text (Snapshot.Free_Space_Bytes));
   end Free_Space_Label;

   function Folder_Contents_Text (Info : Info_Snapshot) return UString is
      Result : Unbounded_String;
      --  "1 item" / "3 items" where the locale's catalog has the plural
      --  message; else the number and the catalog's word.
      Counted : constant String :=
        Files.Localization.Count_Text ("info.contents.items.count", Info.Folder_File_Count);
   begin
      if Counted /= "" then
         Append (Result, Counted);
      else
         Append (Result, Grouped_Integer_Text (Long_Long_Integer (Info.Folder_File_Count)));
         Append (Result, " ");
         Append (Result, Files.Localization.Text ("info.contents.items"));
      end if;
      Append (Result, Files.Localization.Text ("info.contents.separator"));
      Append (Result, Size_Text (Info.Folder_Size_Bytes));
      Append (Result, " ");
      Append (Result, Files.Localization.Text ("info.contents.total"));
      if Info.Folder_Size_Capped then
         Append (Result, " ");
         Append (Result, Files.Localization.Text ("info.contents.capped"));
      end if;

      return Result;
   end Folder_Contents_Text;

   function Label_Render_Color
     (Label : Files.Types.Color_Label)
      return Guikit.Draw.Render_Color is
   begin
      case Label is
         when Files.Types.No_Label => return Guikit.Draw.Muted_Text_Color;
         when Files.Types.Red      => return Guikit.Draw.Accent_Red_Color;
         when Files.Types.Orange   => return Guikit.Draw.Accent_Orange_Color;
         when Files.Types.Yellow   => return Guikit.Draw.Accent_Yellow_Color;
         when Files.Types.Green    => return Guikit.Draw.Accent_Green_Color;
         when Files.Types.Blue     => return Guikit.Draw.Accent_Blue_Color;
         when Files.Types.Purple   => return Guikit.Draw.Accent_Purple_Color;
         when Files.Types.Gray     => return Guikit.Draw.Accent_Gray_Color;
      end case;
   end Label_Render_Color;

   function Info_Metadata_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString
   is
   begin
      if not Available then
         return To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"));
      end if;

      return
        To_Unbounded_String (Humanized_Time_Text (Value, Now));
   end Info_Metadata_Text;

   function Info_Field_Value
     (Info  : Info_Snapshot;
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
      return UString
   is
   begin
      case Field is
         when Info_Name =>
            return Info.Name;
         when Info_Filetype =>
            return Info.Filetype_Detail;
         when Info_Size =>
            return
              (if Info.Size_Available
               then To_Unbounded_String (Size_Text (Info.Size))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when Info_Folder_Size =>
            return Folder_Contents_Text (Info);
         when Info_Created =>
            return Info_Metadata_Text (Info.Creation_Available, Info.Creation_Time, Now);
         when Info_Modified =>
            return Info_Metadata_Text (Info.Modified_Available, Info.Modified_Time, Now);
         when Info_Permissions =>
            return
              (if Length (Info.Permissions) = 0
               then To_Unbounded_String (Files.Localization.Text ("status.missing_metadata"))
               else To_Unbounded_String (Permission_Text (To_String (Info.Permissions))));
         when Info_Metadata_Error =>
            return
              (if Info.Metadata_Error
               then To_Unbounded_String (Files.Localization.Text (To_String (Info.Error_Key)))
               else To_Unbounded_String (Files.Localization.Text ("status.missing_metadata")));
         when Info_Extra =>
            return Info.Filetype_Extra;
         when Info_Owner =>
            return
              (if Info.Owner_Editing then Info.Ownership_Buffer
               elsif Length (Info.Owner_Name) > 0 then Info.Owner_Name
               else To_Unbounded_String
                      (Files.Types.Account_Image (Info.Owner_Id)));
         when Info_Group =>
            return
              (if Info.Group_Editing then Info.Ownership_Buffer
               elsif Length (Info.Group_Name) > 0 then Info.Group_Name
               else To_Unbounded_String
                      (Files.Types.Account_Image (Info.Group_Id)));
      end case;
   end Info_Field_Value;

   function Info_Field_Display_Value
     (Info  : Info_Snapshot;
      Field : Info_Field;
      Now   : Ada.Calendar.Time)
      return UString
   is
      Value : constant UString := Info_Field_Value (Info, Field, Now);
   begin
      if Field /= Info_Extra then
         return Value;
      end if;

      declare
         Raw    : constant String := To_String (Value);
         Result : Unbounded_String;
         Index  : Integer := Raw'First;
      begin
         while Index <= Raw'Last loop
            if Index < Raw'Last
              and then Raw (Index) = '.'
              and then Raw (Index + 1) = ' '
            then
               Append (Result, ".");
               Append (Result, ASCII.LF);
               Index := Index + 2;
            else
               Append (Result, Raw (Index));
               Index := Index + 1;
            end if;
         end loop;

         return Result;
      end;
   end Info_Field_Display_Value;

   function Info_Postfix (Info : Info_Snapshot) return String is
   begin
      return " (" & To_String (Info.Name) & ")";
   end Info_Postfix;

   function Build_Coalesced_Info_Sections
     (Snapshot : View_Snapshot)
      return Coalesced_Section_Vectors.Vector
 is separate;

end Files.Rendering.Labels;
