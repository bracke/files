separate (Check_All)
   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is
      use Tokens;

      Catalog : constant String := Root & "/share/files.catalog";
   begin
      for Item of Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Preserve_Case => True) loop
         if Item.Kind = Literal
           and then not Item.Is_Character
           and then Is_Indirect_Localization_Key (To_String (Item.Text))
         then
            Require_In_Text
              (Catalog,
               "en." & To_String (Item.Text) & " = ",
               Path & ": localization key must exist in share/files.catalog: " & To_String (Item.Text));
         end if;
      end loop;
   end Check_Indirect_Localization_Keys_In_File;
