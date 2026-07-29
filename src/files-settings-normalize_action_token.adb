separate (Files.Settings)
   function Normalize_Action_Token (Token : String) return String is
      Clean : constant String := Trim (Token);
      Plus  : constant Natural := Modifier_Suffix_Start (Clean);
   begin
      if Plus = 0 then
         return Clean;
      end if;

      declare
         Filetype  : constant String := Trim (Clean (Clean'First .. Plus - 1));
         Position  : Natural := Plus + 1;
         Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
         Unknowns  : Unbounded_String := Null_Unbounded_String;

         procedure Add_Modifier (Text : String) is
            Name : constant String := Files.Types.To_Lower (Trim (Text));
         begin
            if Name = "shift" then
               Modifiers (Guikit.Input.Shift_Key) := True;
            elsif Name = "control" then
               Modifiers (Guikit.Input.Control_Key) := True;
            elsif Name = "alt" then
               Modifiers (Guikit.Input.Alt_Key) := True;
            elsif Name = "meta" then
               Modifiers (Guikit.Input.Meta_Key) := True;
            elsif Name /= "" then
               Append (Unknowns, "+");
               Append (Unknowns, Name);
            end if;
         end Add_Modifier;
      begin
         while Position <= Clean'Last loop
            declare
               Last : Natural := Position;
            begin
               while Last <= Clean'Last and then Clean (Last) /= '+' loop
                  Last := Last + 1;
               end loop;

               if Last > Position then
                  Add_Modifier (Clean (Position .. Last - 1));
               end if;

               Position := Last + 1;
            end;
         end loop;

         return Filetype & Modifier_Token (Modifiers) & To_String (Unknowns);
      end;
   end Normalize_Action_Token;
