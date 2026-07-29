separate (Files.Settings)
   procedure Add_Open_Action
     (Settings : in out Settings_Model;
      Token    : String;
      Action   : Open_Action)
   is
      Key : constant String := Normalize_Action_Token (Token);
      Plus : constant Natural := Modifier_Suffix_Start (Key);
      Clean_Action : Open_Action := Action;
   begin
      if Key = ""
        or else (Plus = Key'First)
        or else not Open_Action_Base_Key_Is_Valid ((if Plus = 0 then Key else Key (Key'First .. Plus - 1)))
        or else not Action_Token_Modifiers_Are_Known (Token)
        or else Trim (To_String (Action.Executable)) = ""
        or else Has_Unsafe_Placeholder_Usage (Action)
        or else not Action_Text_Is_Serializable (Action)
      then
         return;
      end if;

      Clean_Action.Executable := To_Unbounded_String (Trim (To_String (Action.Executable)));

      if Settings.Open_Actions.Contains (Key) then
         Settings.Open_Actions.Replace (Key, Clean_Action);
      else
         Settings.Open_Actions.Insert (Key, Clean_Action);
      end if;
   end Add_Open_Action;
