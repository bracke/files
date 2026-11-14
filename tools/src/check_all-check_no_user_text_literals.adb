separate (Check_All)
   procedure Check_No_User_Text_Literals (Path : String) is
      use Tokens;

      Toks  : constant Token_List :=
        Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Preserve_Case => True);
      Index : Positive := Toks.First_Index;

      --  Past the statement that begins at From, to the ";" at its own
      --  parenthesis depth, so a ';' inside its message does not end it.
      function Past_Statement (From : Positive) return Positive is
         Depth : Integer := 0;
         Next  : Positive := From;
      begin
         while Next <= Toks.Last_Index loop
            if Is_Symbol (Toks (Next), "(") then
               Depth := Depth + 1;
            elsif Is_Symbol (Toks (Next), ")") then
               Depth := Depth - 1;
            elsif Depth = 0 and then Is_Symbol (Toks (Next), ";") then
               return Next + 1;
            end if;
            Next := Next + 1;
         end loop;
         return Next;
      end Past_Statement;
   begin
      --  Comments are no tokens: their prose may quote phrases that are
      --  documentation, not hard-coded user-visible string literals.
      while Index <= Toks.Last_Index loop
         if Diagnostic_Pragma_Length (Toks, Index) > 0 then
            Index := Past_Statement (Index);
         else
            declare
               Item : constant Token := Toks (Index);
            begin
               if Item.Kind = Literal
                 and then not Item.Is_Character
                 and then Looks_Like_User_Text (To_String (Item.Text))
               then
                  Report (Path & ":" & Natural'Image (Item.Line)
                     & ": hard-coded user-visible text literal: "
                     & To_String (Item.Text));
               end if;
            end;
            Index := Index + 1;
         end if;
      end loop;
   end Check_No_User_Text_Literals;
