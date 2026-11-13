separate (Check_All)
   procedure Check_Error_Localization_Test_Coverage is
      Catalog      : constant String := Root & "/share/files.catalog";
      Tests        : constant String := Combined_Suite;
      Content      : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Line_First   : Natural := Content'First;
      Line_Last    : Natural := Content'First;
      Separator    : Natural;
      Covered_Key  : Unbounded_String;

      procedure Check_Line (Line : String) is
      begin
         if Starts_With (Line, "en.error.") then
            Separator := Ada.Strings.Fixed.Index (Line, " = ");
            if Separator = 0 then
               return;
            end if;

            Covered_Key := To_Unbounded_String (Line (Line'First + 3 .. Separator - 1));
            Project_Tools.Files.Require_Contains
              (Tests,
               "Add_Error_Key (""" & To_String (Covered_Key) & """);",
               "localization tests must cover recoverable error key " & To_String (Covered_Key));
         end if;
      end Check_Line;
   begin
      while Line_First <= Content'Last loop
         Line_Last := Line_First;
         while Line_Last <= Content'Last and then Content (Line_Last) /= ASCII.LF loop
            Line_Last := Line_Last + 1;
         end loop;

         if Line_Last > Line_First then
            Check_Line (Content (Line_First .. Line_Last - 1));
         end if;

         Line_First := Line_Last + 1;
      end loop;
   end Check_Error_Localization_Test_Coverage;
