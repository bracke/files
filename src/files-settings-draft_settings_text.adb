separate (Files.Settings)
   function Draft_Settings_Text
     (Draft : Settings_Draft)
      return String
   is
      Filetype_Keys : String_Vectors.Vector := Draft.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector := Draft.Filetype_Values;
      Icon_Keys     : String_Vectors.Vector := Draft.Icon_Keys;
      Icon_Values   : String_Vectors.Vector := Draft.Icon_Values;
      Action_Keys   : String_Vectors.Vector := Draft.Open_Action_Keys;
      Action_Values : String_Vectors.Vector := Draft.Open_Action_Commands;
      Result        : Unbounded_String := Null_Unbounded_String;

      procedure Upsert
        (Keys   : in out String_Vectors.Vector;
         Values : in out String_Vectors.Vector;
         Kind   : Draft_Mapping_Kind;
         Key    : UString;
         Value  : UString)
      is
         Key_Text : constant String := Draft_Mapping_Key_Text (Kind, Key);
      begin
         if Length (Key) = 0 and then Length (Value) = 0 then
            return;
         end if;

         for Index in 1 .. Natural (Keys.Length) loop
            if Draft_Mapping_Key_Text (Kind, Keys.Element (Index)) = Key_Text then
               Keys.Replace_Element (Index, To_Unbounded_String (Key_Text));
               Values.Replace_Element (Index, Value);
               return;
            end if;
         end loop;

         Keys.Append (To_Unbounded_String (Key_Text));
         Values.Append (Value);
      end Upsert;

      procedure Append_Line (Text : String := "") is
      begin
         Append (Result, Text);
         Append (Result, ASCII.LF);
      end Append_Line;
   begin
      Upsert
        (Filetype_Keys,
         Filetype_Values,
         Draft_Filetype_Mapping,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Upsert (Icon_Keys, Icon_Values, Draft_Icon_Mapping, Draft.Icon_Filetype, Draft.Icon_Value);
      Upsert
        (Action_Keys,
         Action_Values,
         Draft_Open_Action_Mapping,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);

      Append_Line ("[settings]");
      Append_Line ("default_view_mode = " & To_String (Draft.Default_View_Mode));
      Append_Line ("show_hidden_files = " & To_String (Draft.Show_Hidden_Files));
      Append_Line ("show_file_extensions" & " = " & To_String (Draft.Show_File_Extensions));
      Append_Line ("show_used_space" & " = " & To_String (Draft.Show_Used_Space));
      Append_Line ("show_space_bar" & " = " & To_String (Draft.Show_Space_Bar));
      Append_Line ("sort_field = " & To_String (Draft.Sort_Field_Value));
      Append_Line ("sort_ascending = " & To_String (Draft.Sort_Ascending));
      Append_Line ("theme" & " = " & To_String (Draft.Theme));
      Append_Line ("icon_theme = " & Action_Token_Text (To_String (Draft.Icon_Theme_Name)));
      Append_Line ("font_pixel_size = " & To_String (Draft.Font_Pixel_Size));
      --  Emit the scalar toggles/enum only when the draft carries a value, so a
      --  bare draft round-trips to defaults. Keys are space-free identifiers, so
      --  the assembled literals are never mistaken for user-visible prose.
      if Length (Draft.Use_System_Default_Opener) > 0 then
         Append_Line ("use_system_default_opener" & " = " & To_String (Draft.Use_System_Default_Opener));
      end if;
      if Length (Draft.Group_By) > 0 then
         Append_Line ("group_by" & " = " & To_String (Draft.Group_By));
      end if;
      if Length (Draft.Column_Modified) > 0 then
         Append_Line ("detail_column_modified" & " = " & To_String (Draft.Column_Modified));
      end if;
      if Length (Draft.Column_Size) > 0 then
         Append_Line ("detail_column_size" & " = " & To_String (Draft.Column_Size));
      end if;
      if Length (Draft.Column_Filetype) > 0 then
         Append_Line ("detail_column_filetype" & " = " & To_String (Draft.Column_Filetype));
      end if;
      if Length (Draft.Column_Created) > 0 then
         Append_Line ("detail_column_created" & " = " & To_String (Draft.Column_Created));
      end if;
      if Length (Draft.Column_Permissions) > 0 then
         Append_Line ("detail_column_permissions" & " = " & To_String (Draft.Column_Permissions));
      end if;

      if not Filetype_Keys.Is_Empty then
         Append_Line ("[filetypes]");
         for Index in 1 .. Natural (Filetype_Keys.Length) loop
            Append_Line
              (To_String (Filetype_Keys.Element (Index))
               & " = "
               & Action_Token_Text (To_String (Filetype_Values.Element (Index))));
         end loop;
      end if;

      if not Icon_Keys.Is_Empty then
         Append_Line ("[icons]");
         for Index in 1 .. Natural (Icon_Keys.Length) loop
            Append_Line
              (To_String (Icon_Keys.Element (Index))
               & " = "
               & Action_Token_Text (To_String (Icon_Values.Element (Index))));
         end loop;
      end if;

      if not Action_Keys.Is_Empty then
         Append_Line ("[open-actions]");
         for Index in 1 .. Natural (Action_Keys.Length) loop
            Append_Line (To_String (Action_Keys.Element (Index)) & " = " & To_String (Action_Values.Element (Index)));
         end loop;
      end if;

      return To_String (Result);
   end Draft_Settings_Text;
