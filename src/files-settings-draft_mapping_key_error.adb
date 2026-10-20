separate (Files.Settings)
   function Draft_Mapping_Key_Error
     (Draft : Settings_Draft)
      return String is
   begin
      if (Length (Draft.Filetype_Extension) > 0 or else Length (Draft.Filetype_Value) > 0)
        and then not Mapping_Key_Is_Valid (Normalize_Extension (To_String (Draft.Filetype_Extension)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Index in 1 .. Natural (Draft.Filetype_Keys.Length) loop
         if not Blank_Row (Draft.Filetype_Keys, Draft.Filetype_Values, Index)
           and then not Mapping_Key_Is_Valid
             (Normalize_Extension (To_String (Draft.Filetype_Keys.Element (Index))))
         then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Icon_Filetype) > 0 or else Length (Draft.Icon_Value) > 0)
        and then not Mapping_Key_Is_Valid (Trim (To_String (Draft.Icon_Filetype)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Index in 1 .. Natural (Draft.Icon_Keys.Length) loop
         if not Blank_Row (Draft.Icon_Keys, Draft.Icon_Values, Index)
           and then not Mapping_Key_Is_Valid (Trim (To_String (Draft.Icon_Keys.Element (Index))))
         then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if Length (Draft.Open_Action_Token) > 0 or else Length (Draft.Open_Action_Command) > 0 then
         declare
            Token : constant String := Normalize_Action_Token (To_String (Draft.Open_Action_Token));
            Plus  : constant Natural := Modifier_Suffix_Start (Token);
         begin
            if Token = ""
              or else (Plus = Token'First)
              or else not Open_Action_Base_Key_Is_Valid
                ((if Plus = 0 then Token else Token (Token'First .. Plus - 1)))
              or else not Action_Token_Modifiers_Are_Known (To_String (Draft.Open_Action_Token))
            then
               return "error.settings.invalid_open_action";
            end if;
         end;
      end if;

      for Index in 1 .. Natural (Draft.Open_Action_Keys.Length) loop
         declare
            Key   : constant UString := Draft.Open_Action_Keys.Element (Index);
            Token : constant String := Normalize_Action_Token (To_String (Key));
            Plus  : constant Natural := Modifier_Suffix_Start (Token);
         begin
            if Blank_Row (Draft.Open_Action_Keys, Draft.Open_Action_Commands, Index) then
               null;
            elsif Token = ""
              or else (Plus = Token'First)
              or else not Open_Action_Base_Key_Is_Valid
                ((if Plus = 0 then Token else Token (Token'First .. Plus - 1)))
              or else not Action_Token_Modifiers_Are_Known (To_String (Key))
            then
               return "error.settings.invalid_open_action";
            end if;
         end;
      end loop;

      return "";
   end Draft_Mapping_Key_Error;
