separate (Files.Settings)
   function Validate_Draft
     (Draft : Settings_Draft)
      return Settings_Parse_Result is
   begin
      if not Draft_Mapping_Vectors_Are_Aligned (Draft) then
         return
           (Success   => False,
            Settings  => Default_Settings,
            Error_Key => To_Unbounded_String ("error.settings.invalid"));
      end if;

      declare
         Key_Error : constant String := Draft_Mapping_Key_Error (Draft);
      begin
         if Key_Error /= "" then
            return
              (Success   => False,
               Settings  => Default_Settings,
               Error_Key => To_Unbounded_String (Key_Error));
         end if;
      end;

      declare
         Value_Error : constant String := Draft_Mapping_Value_Error (Draft);
      begin
         if Value_Error /= "" then
            return
              (Success   => False,
               Settings  => Default_Settings,
               Error_Key => To_Unbounded_String (Value_Error));
         end if;
      end;

      return Parse (Draft_Settings_Text (Draft));
   end Validate_Draft;
