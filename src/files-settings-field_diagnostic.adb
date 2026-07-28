separate (Files.Settings)
   function Field_Diagnostic
     (Field : Natural;
      Text  : String)
      return String
   is
      Clean : constant String := Trim (Text);
   begin
      if Contains_Line_Break (Text) then
         case Field is
            when 1 =>
               return "error.settings.invalid_view_mode";
            when 2 | 4 =>
               return "error.settings.invalid_boolean";
            when 5 =>
               return "error.settings.invalid_theme";
            when 3 =>
               return "error.settings.invalid_sort_field";
            when 6 =>
               return "error.settings.invalid_icon_theme";
            when 7 .. 10 =>
               return "error.settings.invalid_mapping";
            when 11 | 12 =>
               return "error.settings.invalid_open_action";
            when others =>
               return "error.settings.invalid";
         end case;
      end if;

      case Field is
         when 1 =>
            declare
               Mode : constant String := Files.Types.To_Lower (Clean);
            begin
               if Mode = "small"
                 or else Mode = "small_icons"
                 or else Mode = "large"
                 or else Mode = "large_icons"
                 or else Mode = "details"
               then
                  return "";
               end if;
               return "error.settings.invalid_view_mode";
            end;
         when 2 | 4 =>
            declare
               Value : constant String := Files.Types.To_Lower (Clean);
            begin
               if Value = "true" or else Value = "false" then
                  return "";
               end if;
               return "error.settings.invalid_boolean";
            end;
         when 5 =>
            declare
               Value : constant String := Files.Types.To_Lower (Clean);
            begin
               if Value = "dark" or else Value = "light" or else Value = "high_contrast" then
                  return "";
               end if;
               return "error.settings.invalid_theme";
            end;
         when 3 =>
            declare
               Value : constant String := Files.Types.To_Lower (Clean);
            begin
               if Value = "name" or else Value = "filetype" or else Value = "size"
                 or else Value = "created" or else Value = "modified"
               then
                  return "";
               end if;
               return "error.settings.invalid_sort_field";
            end;
         when 6 =>
            return (if Icon_Theme_Name_Is_Valid (Clean) then "" else "error.settings.invalid_icon_theme");
         when 7 =>
            declare
               Key : constant String := Normalize_Extension (Clean);
            begin
               return (if not Mapping_Key_Is_Valid (Key) then "error.settings.invalid_mapping" else "");
            end;
         when 8 | 10 =>
            return (if Clean = "" then "error.settings.invalid_mapping" else "");
         when 9 =>
            return (if not Mapping_Key_Is_Valid (Clean) then "error.settings.invalid_mapping" else "");
         when 11 =>
            declare
               Key  : constant String := Normalize_Action_Token (Clean);
               Plus : constant Natural := Modifier_Suffix_Start (Key);
            begin
               if Key = ""
                 or else Plus = Key'First
                 or else not Open_Action_Base_Key_Is_Valid
                   ((if Plus = 0 then Key else Key (Key'First .. Plus - 1)))
                 or else not Action_Token_Modifiers_Are_Known (Clean)
               then
                  return "error.settings.invalid_open_action";
               end if;
               return "";
            end;
         when 12 =>
            declare
               Action : constant Open_Action := Parse_Action (Clean);
            begin
               if To_String (Action.Executable) = "" or else Has_Unsafe_Placeholder_Usage (Action) then
                  return "error.settings.invalid_open_action";
               end if;
               return "";
            end;
         when others =>
            return "error.settings.invalid";
      end case;
   end Field_Diagnostic;
