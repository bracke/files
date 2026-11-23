separate (Check_All)
   function Used_Units (Toks : Tokens.Token_List; Aliases : String; Units : String) return String is
      use Tokens;
      Result : Unbounded_String;
      Index  : Natural := Toks.First_Index;
      Named  : Unbounded_String;
   begin
      while Index <= Toks.Last_Index loop
         if Is_Word (Toks (Index), "use")
           and then Index < Toks.Last_Index
           and then not Is_Word (Toks (Index + 1), "type")
           and then not Is_Word (Toks (Index + 1), "all")
         then
            --  use A.B, C;: each name, spelled out.
            Index := Index + 1;
            while Index <= Toks.Last_Index and then not Is_Symbol (Toks (Index), ";") loop
               if Toks (Index).Kind = Word then
                  Named := Toks (Index).Text;
                  while Index + 2 <= Toks.Last_Index
                    and then Is_Symbol (Toks (Index + 1), ".")
                    and then Toks (Index + 2).Kind = Word
                  loop
                     Append (Named, "." & To_String (Toks (Index + 2).Text));
                     Index := Index + 2;
                  end loop;
                  declare
                     Unit : constant String := Spelled_Out (To_String (Named), Aliases);
                  begin
                     if Has_Line (Units, Unit) and then not Has_Line (To_String (Result), Unit) then
                        Append (Result, Unit & ASCII.LF);
                     end if;
                  end;
               end if;
               Index := Index + 1;
            end loop;
         end if;
         Index := Index + 1;
      end loop;
      return To_String (Result);
   end Used_Units;
