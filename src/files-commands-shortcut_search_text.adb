separate (Files.Commands)
   function Shortcut_Search_Text
     (Id : Command_Id)
      return String
   is
      Primary   : constant String := Shortcut_Text (Shortcut_For (Id));
      Secondary : constant String := Shortcut_Text (Secondary_Shortcut_For (Id));

      function Search_Aliases (Text : String) return String is
         Shift_Control_Prefix : constant String := "shift+control+";
         Result : Unbounded_String := To_Unbounded_String (Text);

         procedure Add_Control_Alias is
         begin
            if Text'Length > 8
              and then Text (Text'First .. Text'First + 7) = "control+"
            then
               Append (Result, ASCII.HT);
               Append (Result, "ctrl+");
               Append (Result, Text (Text'First + 8 .. Text'Last));
            end if;
         end Add_Control_Alias;

         procedure Add_Alt_Alias is
         begin
            if Text'Length > 4
              and then Text (Text'First .. Text'First + 3) = "alt+"
            then
               Append (Result, ASCII.HT);
               Append (Result, "option+");
               Append (Result, Text (Text'First + 4 .. Text'Last));
            end if;
         end Add_Alt_Alias;

         procedure Add_Shift_Control_Aliases is
         begin
            if Text'Length > Shift_Control_Prefix'Length
              and then Text (Text'First .. Text'First + Shift_Control_Prefix'Length - 1) =
                Shift_Control_Prefix
            then
               declare
                  Suffix : constant String :=
                    Text (Text'First + Shift_Control_Prefix'Length .. Text'Last);
               begin
                  Append (Result, ASCII.HT);
                  Append (Result, "shift+ctrl+");
                  Append (Result, Suffix);
                  Append (Result, ASCII.HT);
                  Append (Result, "control+shift+");
                  Append (Result, Suffix);
                  Append (Result, ASCII.HT);
                  Append (Result, "ctrl+shift+");
                  Append (Result, Suffix);
               end;
            end if;
         end Add_Shift_Control_Aliases;

         procedure Add_Key_Alias
           (Canonical : String;
            Alias     : String)
         is
            Position : constant Natural := Ada.Strings.Fixed.Index (Text, Canonical);
         begin
            if Position > 0 then
               Append (Result, ASCII.HT);
               if Position > Text'First then
                  Append (Result, Text (Text'First .. Position - 1));
               end if;
               Append (Result, Alias);
            end if;
         end Add_Key_Alias;
      begin
         Add_Control_Alias;
         Add_Alt_Alias;
         Add_Shift_Control_Aliases;
         Add_Key_Alias ("delete", "del");
         Add_Key_Alias ("escape", "esc");
         Add_Key_Alias ("return", "enter");
         return To_String (Result);
      end Search_Aliases;
   begin
      if Primary = "" then
         return Search_Aliases (Secondary);
      elsif Secondary = "" then
         return Search_Aliases (Primary);
      else
         return Search_Aliases (Primary) & " " & Search_Aliases (Secondary);
      end if;
   end Shortcut_Search_Text;
