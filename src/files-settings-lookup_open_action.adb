separate (Files.Settings)
   function Lookup_Open_Action
     (Settings  : Settings_Model;
      Filetype  : String;
      Modifiers : Guikit.Input.Modifier_Set)
      return Action_Lookup_Result
   is
      Base_Token : constant String := Trim (Filetype);
      Full_Token : constant String := Base_Token & Modifier_Token (Modifiers);
   begin
      if Base_Token = "" then
         --  Unknown filetype (extension not in the mapping table). Still try
         --  the host opener — xdg-open will sniff content even without an
         --  explicit MIME — when the user has not opted out.
         if Settings.Use_System_Default_Opener then
            declare
               Fallback : constant Action_Lookup_Result :=
                 System_Default_Opener_Action ("");
            begin
               if Fallback.Found then
                  return Fallback;
               end if;
            end;
         end if;

         return
           (Found     => False,
            Action    => Make_Action ("", String_Vectors.Empty_Vector),
            Token     => Null_Unbounded_String,
            Error_Key => To_Unbounded_String ("error.open_action.missing"),
            System_Fallback => False);
      end if;

      if Settings.Open_Actions.Contains (Full_Token) then
         return
           (Found     => True,
            Action    => Settings.Open_Actions.Element (Full_Token),
            Token     => To_Unbounded_String (Full_Token),
            Error_Key => Null_Unbounded_String,
            System_Fallback => False);
      elsif Settings.Open_Actions.Contains (Base_Token) then
         return
           (Found     => True,
            Action    => Settings.Open_Actions.Element (Base_Token),
            Token     => To_Unbounded_String (Base_Token),
            Error_Key => Null_Unbounded_String,
            System_Fallback => False);
      end if;

      --  Per-filetype config didn't match; fall through to the host opener
      --  when the user has not opted out via Use_System_Default_Opener.
      if Settings.Use_System_Default_Opener then
         declare
            Fallback : constant Action_Lookup_Result :=
              System_Default_Opener_Action (Base_Token);
         begin
            if Fallback.Found then
               return Fallback;
            end if;
         end;
      end if;

      return
        (Found     => False,
         Action    => Make_Action ("", String_Vectors.Empty_Vector),
         Token     => To_Unbounded_String (Full_Token),
         Error_Key => To_Unbounded_String ("error.open_action.missing"),
         System_Fallback => False);
   end Lookup_Open_Action;
