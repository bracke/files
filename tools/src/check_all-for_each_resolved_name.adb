separate (Check_All)
   procedure For_Each_Resolved_Name
     (Toks    : Tokens.Token_List;
      Aliases : String;
      Units   : String;
      Visit   : not null access procedure (Name : String; Next : Positive))
   is
      use Tokens;
      Used    : constant String := Used_Units (Toks, Aliases, Units);
      --  use Ada; makes Directories.Delete_File Ada.Directories.Delete_File.
      Leading : constant String := Used_Units (Toks, Aliases, Units, Prefixes => True);
      Index : Natural := Toks.First_Index;

      --  Whether a with or use clause starts at Index: "use" anywhere, "with"
      --  where a context clause can stand (not an aggregate's or an aspect's).
      function Starts_Clause (At_Index : Positive) return Boolean is
        (Is_Word (Toks (At_Index), "use")
         or else (Is_Word (Toks (At_Index), "with")
                  and then (At_Index = Toks.First_Index
                            or else Is_Symbol (Toks (At_Index - 1), ";")
                            or else Is_Word (Toks (At_Index - 1), "private")
                            or else Is_Word (Toks (At_Index - 1), "limited"))));
   begin
      while Index <= Toks.Last_Index loop
         if Starts_Clause (Index) then
            while Index <= Toks.Last_Index and then not Is_Symbol (Toks (Index), ";") loop
               Index := Index + 1;
            end loop;
            Index := Index + 1;
         elsif Toks (Index).Kind = Word
           and then (Index = Toks.First_Index or else not Is_Symbol (Toks (Index - 1), "."))
         then
            declare
               Name : Unbounded_String := Toks (Index).Text;
               Last : Positive := Index;

               procedure Through_Use (Unit : String; Number : Positive) is
                  pragma Unreferenced (Number);
               begin
                  Visit (Unit & "." & To_String (Name), Last + 1);
               end Through_Use;
            begin
               while Last + 2 <= Toks.Last_Index
                 and then Is_Symbol (Toks (Last + 1), ".")
                 and then Toks (Last + 2).Kind = Word
               loop
                  Append (Name, "." & To_String (Toks (Last + 2).Text));
                  Last := Last + 2;
               end loop;
               Visit (Spelled_Out (To_String (Name), Aliases), Last + 1);
               For_Each_Line (Used, Through_Use'Access);
               For_Each_Line (Leading, Through_Use'Access);
               Index := Last + 1;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end For_Each_Resolved_Name;
