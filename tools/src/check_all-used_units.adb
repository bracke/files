separate (Check_All)
   function Used_Units
     (Toks     : Tokens.Token_List;
      Aliases  : String;
      Units    : String;
      Prefixes : Boolean := False) return String
   is
      use Tokens;
      Result   : Unbounded_String;
      --  The used packages that only lead to a unit of Units ("ada", "gnat",
      --  "ada.streams"): a later use or name may continue from them.
      Leading  : Unbounded_String;
      Index    : Natural := Toks.First_Index;
      Named    : Unbounded_String;

      function Leads_To_Unit (Name : String) return Boolean is
        (Ada.Strings.Fixed.Index (ASCII.LF & Units, ASCII.LF & Name & ".") > 0);

      procedure Take (Unit : String) is
      begin
         if Has_Line (Units, Unit) then
            if not Has_Line (To_String (Result), Unit) then
               Append (Result, Unit & ASCII.LF);
            end if;
         elsif Leads_To_Unit (Unit) and then not Has_Line (To_String (Leading), Unit) then
            Append (Leading, Unit & ASCII.LF);
         end if;
      end Take;

      procedure Through_Leading (Prefix : String; Number : Positive) is
         pragma Unreferenced (Number);
      begin
         Take (Prefix & "." & To_String (Named));
      end Through_Leading;
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
                     Earlier : constant String := To_String (Leading);
                  begin
                     Take (Spelled_Out (To_String (Named), Aliases));
                     --  use Ada.Streams; use Stream_IO;
                     For_Each_Line (Earlier, Through_Leading'Access);
                  end;
               end if;
               Index := Index + 1;
            end loop;
         end if;
         Index := Index + 1;
      end loop;
      return To_String (if Prefixes then Leading else Result);
   end Used_Units;
