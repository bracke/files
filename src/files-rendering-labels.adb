with Ada.Strings;
with Files.Localization;

package body Files.Rendering.Labels is

   function Command_Label (Id : Files.Commands.Command_Id) return UString is
     (To_Unbounded_String (Files.Localization.Text (Files.Commands.Name_Key (Id))));

   function Bottom_Command_Label (Id : Files.Commands.Command_Id) return UString is
      function Short (Key : String) return UString is (To_Unbounded_String (Files.Localization.Text (Key)));
   begin
      case Id is
         when Files.Commands.Select_Small_Icons_Command => return Short ("command.view.small.short");
         when Files.Commands.Select_Large_Icons_Command => return Short ("command.view.large.short");
         when Files.Commands.Select_Details_Command     => return Short ("command.view.details.short");
         when Files.Commands.Toggle_Info_Pane_Command   => return Short ("command.info.toggle.short");
         when Files.Commands.Toggle_Sort_Menu_Command   => return Short ("command.sort.name");
         when others                                    => return Command_Label (Id);
      end case;
   end Bottom_Command_Label;

   function Sort_Field_Label (Field : Files.Types.Sort_Field) return String is
     (Files.Localization.Text (Files.Commands.Sort_Label_Key (Field)));

   function Direction_Text (Ascending : Boolean) return String is
     (Files.Localization.Text ((if Ascending then "sort.direction.ascending" else "sort.direction.descending")));

   function Sort_Button_Label (Field : Files.Types.Sort_Field; Ascending : Boolean) return UString is
     (To_Unbounded_String (Sort_Field_Label (Field) & " " & Direction_Text (Ascending)));

   function View_Mode_Label (Mode : Files.Preference_Types.View_Mode) return String is
   begin
      case Mode is
         when Files.Preference_Types.Small_Icons => return Files.Localization.Text ("command.view.small");
         when Files.Preference_Types.Large_Icons => return Files.Localization.Text ("command.view.large");
         when Files.Preference_Types.Details     => return Files.Localization.Text ("command.view.details");
      end case;
   end View_Mode_Label;

   function Count_Status_Text (Snapshot : View_Snapshot) return UString is
      --  Each count and its localized word; only spaces and punctuation are
      --  literals here.
      Selected : constant String :=
        Grouped_Natural_Text (Snapshot.Selected_Count) & " " & Files.Localization.Text ("status.selected");
   begin
      return
        To_Unbounded_String
          (Grouped_Natural_Text (Snapshot.Hidden_Count) & " " & Files.Localization.Text ("status.hidden")
           & "  "
           & Grouped_Natural_Text (Snapshot.Visible_Count) & " " & Files.Localization.Text ("status.visible")
           & "  "
           & Selected
           & (if Snapshot.Selected_Count >= 1
              then " (" & Size_Text (Snapshot.Selection_Total_Bytes)
                   & (if Snapshot.Selection_Total_Pending then " ..." else "") & ")"
              else ""));
   end Count_Status_Text;

   function Compact_Count_Status_Text (Snapshot : View_Snapshot) return String is
     (Grouped_Natural_Text (Snapshot.Hidden_Count) & "/"
      & Grouped_Natural_Text (Snapshot.Visible_Count) & "/"
      & Grouped_Natural_Text (Snapshot.Selected_Count));

   function Count_Legend_Text return String is
     (" ("
      & Files.Localization.Text ("status.hidden") & " / "
      & Files.Localization.Text ("status.visible") & " / "
      & Files.Localization.Text ("status.selected")
      & ")");

   function Bottom_Info_Text (Snapshot : View_Snapshot) return UString is
     (if Length (Snapshot.Last_Error_Key) > 0 then Snapshot.Last_Error_Text else Count_Status_Text (Snapshot));

   function Main_View_Accessible_Description (Snapshot : View_Snapshot) return UString is
     (To_Unbounded_String
        (Files.Localization.Text ("settings.default_view") & ": " & View_Mode_Label (Snapshot.View_Mode) & "  ")
      & Count_Status_Text (Snapshot));

   function Empty_State_Key (Snapshot : View_Snapshot) return String is
     (if Snapshot.Item_Count = 0 and then Snapshot.In_Recent_View then "recent.empty"
      elsif Snapshot.Item_Count = 0 then "status.empty_directory"
      elsif Snapshot.Visible_Count = 0 and then Length (Snapshot.Filter_Text) > 0 then "status.empty_filter"
      else "");

   function Info_Value (Label_Key : String; Value : String) return UString is
     (To_Unbounded_String (Files.Localization.Text (Label_Key) & ": " & Value));

   function Labelled_Time_Text
     (Label_Key : String;
      Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString is
     (Info_Value (Label_Key, To_String (Info_Metadata_Text (Available, Value, Now))));

   function Detail_Names return Detail_Column_Texts is
     ([Files.Preference_Types.Name_Column        => To_Unbounded_String (Files.Localization.Text ("details.name")),
       Files.Preference_Types.Modified_Column    => To_Unbounded_String (Files.Localization.Text ("details.modified")),
       Files.Preference_Types.Size_Column        => To_Unbounded_String (Files.Localization.Text ("details.size")),
       Files.Preference_Types.Filetype_Column    => To_Unbounded_String (Files.Localization.Text ("details.filetype")),
       Files.Preference_Types.Created_Column     => To_Unbounded_String (Files.Localization.Text ("details.created")),
       Files.Preference_Types.Permissions_Column =>
         To_Unbounded_String (Files.Localization.Text ("details.permissions"))]);

   function Item_Accessible_Description
     (Names   : Detail_Column_Texts;
      Cells   : Detail_Column_Texts;
      Order   : Files.Preference_Types.Detail_Column_Order;
      Visible : Files.Preference_Types.Detail_Column_Visibility;
      Item    : Item_Snapshot;
      Details : Boolean)
      return UString
   is
      use type Files.Preference_Types.Detail_Column;
      Result : UString;
   begin
      if not Details then
         return Item.Filetype_Detail;
      end if;
      --  The name is the node's own name, so it is not said again.
      for Column of Order loop
         if Column /= Files.Preference_Types.Name_Column
           and then Visible (Column)
           and then Length (Cells (Column)) > 0
         then
            declare
               Field : constant String :=
                 Files.Localization.Label_Value (To_String (Names (Column)), To_String (Cells (Column)));
            begin
               Result :=
                 (if Length (Result) = 0 then To_Unbounded_String (Field)
                  else To_Unbounded_String
                    (Files.Localization.Text
                       ("accessibility.item.fields",
                        Files.Localization.Argument_List'
                          [(To_Unbounded_String ("first"), Result),
                           (To_Unbounded_String ("rest"), To_Unbounded_String (Field))])));
            end;
         end if;
      end loop;
      return Result;
   end Item_Accessible_Description;

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
      --  The word in the plural form the count takes ("1 item", "3 items")
      --  where the locale's catalog has the plural message, else the
      --  catalog's word. The number itself is written in the number locale's
      --  digits and grouping, like the size beside it.
      Plural : constant String := Files.Localization.Count_Text ("info.contents.items.word", Info.Folder_File_Count);
   begin
      Append (Result, Grouped_Natural_Text (Info.Folder_File_Count));
      Append (Result, " ");
      Append (Result, (if Plural /= "" then Plural else Files.Localization.Text ("info.contents.items")));
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
     (Label : Files.Preference_Types.Color_Label)
      return Guikit.Draw.Render_Color is
   begin
      case Label is
         when Files.Preference_Types.No_Label => return Guikit.Draw.Muted_Text_Color;
         when Files.Preference_Types.Red      => return Guikit.Draw.Accent_Red_Color;
         when Files.Preference_Types.Orange   => return Guikit.Draw.Accent_Orange_Color;
         when Files.Preference_Types.Yellow   => return Guikit.Draw.Accent_Yellow_Color;
         when Files.Preference_Types.Green    => return Guikit.Draw.Accent_Green_Color;
         when Files.Preference_Types.Blue     => return Guikit.Draw.Accent_Blue_Color;
         when Files.Preference_Types.Purple   => return Guikit.Draw.Accent_Purple_Color;
         when Files.Preference_Types.Gray     => return Guikit.Draw.Accent_Gray_Color;
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

   function Detail_Time_Text
     (Available : Boolean;
      Value     : Ada.Calendar.Time;
      Now       : Ada.Calendar.Time)
      return UString renames Info_Metadata_Text;

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
