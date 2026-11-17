separate (Check_All)
   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is
      use Tokens;

      Items : constant Token_Vectors.Vector :=
        Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Preserve_Case => True);
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         declare
            Item : constant Token := Items (Index);
            --  A literal the code completes at run time ("time.month" &
            --  Image) is a fragment only when '&' follows it; a literal that
            --  merely begins some catalog key is a key, possibly truncated.
            Joined : constant Boolean :=
              Index < Items.Last_Index and then Is_Symbol (Items (Index + 1), "&");
         begin
            if Item.Kind = Literal
              and then not Item.Is_Character
              and then Is_Indirect_Localization_Key (To_String (Item.Text))
              and then not (Joined and then Is_Key_Fragment (To_String (Item.Text)))
            then
               Require_Catalog_Key (Path, To_String (Item.Text));
            end if;
         end;
      end loop;
   end Check_Indirect_Localization_Keys_In_File;
