separate (Files.Settings.Parse)
   procedure Parse_Open_Actions_Line
     (Key, Setting_Key, Value, Raw_Value : String; Err : out Unbounded_String)
   is
      pragma Unreferenced (Setting_Key, Value);
      Normalized_Key : constant String := Normalize_Action_Token (Key);
      Action : constant Open_Action := Parse_Action (Raw_Value);
      Plus   : constant Natural := Modifier_Suffix_Start (Normalized_Key);
   begin
      Err := Null_Unbounded_String;
      if Key = ""
        or else Normalized_Key = ""
        or else (Plus = Normalized_Key'First)
        or else not Open_Action_Base_Key_Is_Valid
          ((if Plus = 0
            then Normalized_Key
            else Normalized_Key (Normalized_Key'First .. Plus - 1)))
        or else not Action_Token_Modifiers_Are_Known (Key)
        or else To_String (Action.Executable) = ""
        or else Open_Actions.Has_Unsafe_Placeholder_Usage (Action)
        or else not Action_Text_Is_Serializable (Action)
      then
         Err := To_Unbounded_String ("error.settings.invalid_open_action");
         return;
      end if;
      Add_Open_Action (Settings, Key, Action);
   end Parse_Open_Actions_Line;
