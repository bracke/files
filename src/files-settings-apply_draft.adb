separate (Files.Settings)
   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result
   is
      Parsed : constant Settings_Parse_Result := Validate_Draft (Draft);
      Result : Settings_Model := Settings;
      Filetype_Keys : String_Vectors.Vector := Draft.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector := Draft.Filetype_Values;
      Icon_Keys     : String_Vectors.Vector := Draft.Icon_Keys;
      Icon_Values   : String_Vectors.Vector := Draft.Icon_Values;
      Action_Keys   : String_Vectors.Vector := Draft.Open_Action_Keys;
      Action_Values : String_Vectors.Vector := Draft.Open_Action_Commands;

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
   begin
      if not Parsed.Success then
         return
           (Success   => False,
            Settings  => Settings,
            Error_Key => Parsed.Error_Key);
      end if;

      Result.Default_View := Parsed.Settings.Default_View;
      Result.Show_Hidden_Files := Parsed.Settings.Show_Hidden_Files;
      Result.Show_File_Extensions := Parsed.Settings.Show_File_Extensions;
      Result.Show_Used_Space := Parsed.Settings.Show_Used_Space;
      Result.Show_Space_Bar := Parsed.Settings.Show_Space_Bar;
      Result.Sort_Field_Value := Parsed.Settings.Sort_Field_Value;
      Result.Sort_Ascending := Parsed.Settings.Sort_Ascending;
      Result.Theme := Parsed.Settings.Theme;
      Result.Icon_Theme_Name := Parsed.Settings.Icon_Theme_Name;
      Result.Font_Pixel_Size := Parsed.Settings.Font_Pixel_Size;
      Result.Window_Width := Settings.Window_Width;
      Result.Window_Height := Settings.Window_Height;
      Result.Info_Pane_Open := Settings.Info_Pane_Open;
      Result.Favorite_Paths := Settings.Favorite_Paths;
      Result.Recent_Paths_Value := Settings.Recent_Paths_Value;
      Result.Labels := Settings.Labels;
      --  The pane now edits these directly, so take them from the parsed draft.
      --  Column order and per-column widths are not pane-editable, so they keep
      --  their existing values (Result starts as a copy of Settings).
      Result.Use_System_Default_Opener := Parsed.Settings.Use_System_Default_Opener;
      Result.Group_By := Parsed.Settings.Group_By;
      Result.Column_Visible := Parsed.Settings.Column_Visible;
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

      Result.Extension_Filetypes.Clear;
      for Index in 1 .. Natural (Filetype_Keys.Length) loop
         Add_Extension_Mapping
           (Result,
            To_String (Filetype_Keys.Element (Index)),
            To_String (Filetype_Values.Element (Index)));
      end loop;

      Result.Icon_Mappings.Clear;
      for Index in 1 .. Natural (Icon_Keys.Length) loop
         Add_Icon_Mapping
           (Result,
            To_String (Icon_Keys.Element (Index)),
            To_String (Icon_Values.Element (Index)));
      end loop;

      Result.Open_Actions.Clear;
      for Index in 1 .. Natural (Action_Keys.Length) loop
         Add_Open_Action
           (Result,
            To_String (Action_Keys.Element (Index)),
            Parse_Action (To_String (Action_Values.Element (Index))));
      end loop;
      return
        (Success   => True,
         Settings  => Result,
         Error_Key => Null_Unbounded_String);
   end Apply_Draft;
