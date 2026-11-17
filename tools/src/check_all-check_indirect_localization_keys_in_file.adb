separate (Check_All)
   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is
      use Tokens;

   begin
      for Item of Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Preserve_Case => True) loop
         if Item.Kind = Literal
           and then not Item.Is_Character
           and then Is_Indirect_Localization_Key (To_String (Item.Text))
           and then not Is_Key_Fragment (To_String (Item.Text))
         then
            Require_Catalog_Key (Path, To_String (Item.Text));
         end if;
      end loop;
   end Check_Indirect_Localization_Keys_In_File;
