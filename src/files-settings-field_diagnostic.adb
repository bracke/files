separate (Files.Settings)
   function Field_Diagnostic
     (Field : Natural;
      Text  : String)
      return String
   is
      Clean : constant String := Trim (Text);

      --  The settings editor's scalar field indices, in its historical order.
      Scalar_Fields : constant array (Positive range 1 .. 6) of Scalar_Setting :=
        [Default_View_Mode_Setting,
         Show_Hidden_Files_Setting,
         Sort_Field_Setting,
         Sort_Ascending_Setting,
         Theme_Setting,
         Icon_Theme_Setting];
   begin
      if Field in Scalar_Fields'Range then
         if Contains_Nul (Text) or else Contains_Line_Break (Text) then
            return Scalar_Error_Key (Scalar_Fields (Field));
         end if;

         declare
            Scratch : Settings_Model;
            Error   : Unbounded_String;
         begin
            Set_Scalar (Scratch, Scalar_Fields (Field), Clean, Error);
            return To_String (Error);
         end;
      end if;

      if Contains_Nul (Text) or else Contains_Line_Break (Text) then
         case Field is
            when 7 .. 10 =>
               return "error.settings.invalid_mapping";
            when 11 | 12 =>
               return "error.settings.invalid_open_action";
            when others =>
               return "error.settings.invalid";
         end case;
      end if;

      case Field is
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
