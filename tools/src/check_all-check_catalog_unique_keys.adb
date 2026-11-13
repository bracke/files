separate (Check_All)
   procedure Check_Catalog_Unique_Keys is
      package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Catalog     : constant String := Root & "/share/files.catalog";
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Seen        : String_Sets.Set;
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Check_Line (Raw : String) is
         Line   : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Line = "" or else Starts_With (Line, "#") then
            return;
         elsif Equals = 0 then
            return;
         end if;

         declare
            Key : constant String :=
              Ada.Strings.Fixed.Trim (Line (Line'First .. Equals - 1), Ada.Strings.Both);
         begin
            if Seen.Contains (Key) then
               Put_Line
                 (Standard_Error,
                  Catalog & ":" & Natural'Image (Line_Number) & ": duplicate localization key: " & Key);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;

            Seen.Insert (Key);
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
   end Check_Catalog_Unique_Keys;
