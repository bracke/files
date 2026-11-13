separate (Check_All)
   procedure Check_Catalog_Format is
      Catalog     : constant String := Root & "/share/files.catalog";
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail
        (Message : String)
      is
      begin
         Put_Line
           (Standard_Error,
            Catalog & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      function Is_Key_Character
        (Char : Character)
         return Boolean is
      begin
         return
           (Char >= 'a' and then Char <= 'z')
           or else (Char >= '0' and then Char <= '9')
           or else Char = '.'
           or else Char = '_';
      end Is_Key_Character;

      function Is_Locale_Character
        (Char : Character)
         return Boolean is
      begin
         return
           (Char >= 'a' and then Char <= 'z')
           or else (Char >= 'A' and then Char <= 'Z')
           or else (Char >= '0' and then Char <= '9')
           or else Char = '_'
           or else Char = '-';
      end Is_Locale_Character;

      function Is_Localized_Key
        (Key : String)
         return Boolean
      is
         Dot : constant Natural := Ada.Strings.Fixed.Index (Key, ".");
      begin
         if Dot <= Key'First or else Dot = Key'Last then
            return False;
         end if;

         for Position in Key'First .. Dot - 1 loop
            if not Is_Locale_Character (Key (Position)) then
               return False;
            end if;
         end loop;

         for Position in Dot + 1 .. Key'Last loop
            if not Is_Key_Character (Key (Position)) then
               return False;
            end if;
         end loop;

         return True;
      end Is_Localized_Key;

      procedure Check_Line (Raw : String) is
         Line   : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Line = "" or else Starts_With (Line, "#") then
            return;
         elsif Equals = 0 then
            Fail ("localization catalog entry must contain an equals sign");
         elsif Equals = Line'First then
            Fail ("localization catalog entry must contain a key before the equals sign");
         elsif Line (Equals - 1) /= ' ' then
            Fail ("localization catalog entry must use ' = ' between key and value");
         elsif Equals < Line'Last and then Line (Equals + 1) /= ' ' then
            Fail ("localization catalog entry must use ' = ' between key and value");
         end if;

         declare
            Key : constant String :=
              Ada.Strings.Fixed.Trim (Line (Line'First .. Equals - 1), Ada.Strings.Both);
         begin
            if Key = "default_locale" then
               null;
            elsif not Is_Localized_Key (Key) then
               Fail ("localization catalog key must be locale-prefixed and use stable key characters");
            end if;
         end;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Catalog_Format;
