separate (Check_All)
   procedure Check_Catalog_Unique_Keys is
      package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Catalog     : constant String := Root & "/share/files.catalog";
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Seen        : String_Sets.Set;

      procedure Check_Line (Raw : String; Number : Positive) is
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
               Report (Catalog & ":" & Natural'Image (Number) & ": duplicate localization key: " & Key);
            end if;

            Seen.Include (Key);
         end;
      end Check_Line;
   begin
      For_Each_Line (Content, Check_Line'Access);
   end Check_Catalog_Unique_Keys;
