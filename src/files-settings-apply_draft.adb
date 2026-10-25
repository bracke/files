separate (Files.Settings)
   function Apply_Draft
     (Settings : Settings_Model;
      Draft    : Settings_Draft)
      return Settings_Parse_Result
   is
      Parsed : constant Settings_Parse_Result := Validate_Draft (Draft);
      Result : Settings_Model := Settings;
      Rows            : constant Settings_Draft := With_Pending_Rows (Draft);
      Filetype_Keys   : String_Vectors.Vector renames Rows.Filetype_Keys;
      Filetype_Values : String_Vectors.Vector renames Rows.Filetype_Values;
      Icon_Keys       : String_Vectors.Vector renames Rows.Icon_Keys;
      Icon_Values     : String_Vectors.Vector renames Rows.Icon_Values;
      Action_Keys     : String_Vectors.Vector renames Rows.Open_Action_Keys;
      Action_Values   : String_Vectors.Vector renames Rows.Open_Action_Commands;
   begin
      if not Parsed.Success then
         return
           (Success   => False,
            Settings  => Settings,
            Error_Key => Parsed.Error_Key);
      end if;

      --  The pane-edited scalar settings come from the parsed draft; every other
      --  scalar (window size, info pane, column order and widths) and the
      --  favorites, recent items and labels keep their live values, since
      --  Result starts as a copy of Settings. Each value travels as its
      --  canonical text, which Set_Scalar always accepts.
      for Setting in Scalar_Setting loop
         if Is_Pane_Setting (Setting) then
            declare
               Error : Unbounded_String;
            begin
               Set_Scalar (Result, Setting, Scalar_Text (Parsed.Settings, Setting), Error);
               if Length (Error) > 0 then
                  return
                    (Success   => False,
                     Settings  => Settings,
                     Error_Key => Error);
               end if;
            end;
         end if;
      end loop;

      Result.Extension_Filetypes.Clear;
      for Index in 1 .. Natural (Filetype_Keys.Length) loop
         if not Blank_Row (Filetype_Keys, Filetype_Values, Index) then
            Add_Extension_Mapping
              (Result,
               To_String (Filetype_Keys.Element (Index)),
               To_String (Filetype_Values.Element (Index)));
         end if;
      end loop;

      Result.Icon_Mappings.Clear;
      for Index in 1 .. Natural (Icon_Keys.Length) loop
         if not Blank_Row (Icon_Keys, Icon_Values, Index) then
            Add_Icon_Mapping
              (Result,
               To_String (Icon_Keys.Element (Index)),
               To_String (Icon_Values.Element (Index)));
         end if;
      end loop;

      Result.Open_Actions.Clear;
      for Index in 1 .. Natural (Action_Keys.Length) loop
         if not Blank_Row (Action_Keys, Action_Values, Index) then
            Add_Open_Action
              (Result,
               To_String (Action_Keys.Element (Index)),
               Parse_Action (To_String (Action_Values.Element (Index))));
         end if;
      end loop;
      return
        (Success   => True,
         Settings  => Result,
         Error_Key => Null_Unbounded_String);
   end Apply_Draft;
