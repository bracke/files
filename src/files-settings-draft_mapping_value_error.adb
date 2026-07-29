separate (Files.Settings)
   function Draft_Mapping_Value_Error
     (Draft : Settings_Draft)
      return String is
   begin
      if (Length (Draft.Filetype_Extension) > 0 or else Length (Draft.Filetype_Value) > 0)
        and then not Mapping_Value_Is_Valid (Trim (To_String (Draft.Filetype_Value)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Value of Draft.Filetype_Values loop
         if not Mapping_Value_Is_Valid (Trim (To_String (Value))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Icon_Filetype) > 0 or else Length (Draft.Icon_Value) > 0)
        and then not Mapping_Value_Is_Valid (Trim (To_String (Draft.Icon_Value)))
      then
         return "error.settings.invalid_mapping";
      end if;

      for Value of Draft.Icon_Values loop
         if not Mapping_Value_Is_Valid (Trim (To_String (Value))) then
            return "error.settings.invalid_mapping";
         end if;
      end loop;

      if (Length (Draft.Open_Action_Token) > 0 or else Length (Draft.Open_Action_Command) > 0)
        and then Contains_Line_Break (To_String (Draft.Open_Action_Command))
      then
         return "error.settings.invalid_open_action";
      end if;

      for Value of Draft.Open_Action_Commands loop
         if Contains_Line_Break (To_String (Value)) then
            return "error.settings.invalid_open_action";
         end if;
      end loop;

      return "";
   end Draft_Mapping_Value_Error;
