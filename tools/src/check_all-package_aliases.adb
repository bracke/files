separate (Check_All)
   function Package_Aliases (Units : String) return String is
      use Tokens;
      --  Every package renaming or instantiation in src/, "scope:alias=named" a line.
      Candidates : Unbounded_String;
      Result     : Unbounded_String;
      Grew       : Boolean := True;

      procedure Collect (Path : String) is
         Toks  : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Scope : constant String := Unit_Of_File (Path);
         Index : Natural;
         Named : Unbounded_String;
      begin
         for Start in Toks.First_Index .. Toks.Last_Index loop
            if Is_Word (Toks (Start), "package")
              and then Start + 3 <= Toks.Last_Index
              and then Toks (Start + 1).Kind = Word
            then
               if Is_Word (Toks (Start + 2), "renames") then
                  Index := Start + 3;
               elsif Is_Word (Toks (Start + 2), "is") and then Is_Word (Toks (Start + 3), "new") then
                  Index := Start + 4;
               else
                  Index := 0;
               end if;
               if Index in Toks.First_Index .. Toks.Last_Index and then Toks (Index).Kind = Word then
                  Named := Toks (Index).Text;
                  while Index + 2 <= Toks.Last_Index
                    and then Is_Symbol (Toks (Index + 1), ".")
                    and then Toks (Index + 2).Kind = Word
                  loop
                     Append (Named, "." & To_String (Toks (Index + 2).Text));
                     Index := Index + 2;
                  end loop;
                  Append (Candidates,
                          Scope & ":" & To_String (Toks (Start + 1).Text) & "=" & To_String (Named) & ASCII.LF);
               end if;
            end if;
         end loop;
      end Collect;

      procedure Take (Line : String; Number : Positive) is
         pragma Unreferenced (Number);
         Colon  : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
         Scope  : constant String := Line (Line'First .. Colon - 1);
         Alias  : constant String := Line (Colon + 1 .. Equals - 1);
         --  A renaming of a renaming reads the aliases its own unit sees.
         Named  : constant String :=
           Spelled_Out (Line (Equals + 1 .. Line'Last), Aliases_Seen_By (To_String (Result), Scope));
         Entry_Line : constant String := Scope & ":" & Alias & "=" & Named;
      begin
         if Has_Line (Units, Named) and then not Has_Line (To_String (Result), Entry_Line) then
            Append (Result, Entry_Line & ASCII.LF);
            Grew := True;
         end if;
      end Take;
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         Collect (To_String (Item));
      end loop;
      --  A renaming of a renaming is followed until nothing more is found.
      while Grew loop
         Grew := False;
         For_Each_Line (To_String (Candidates), Take'Access);
      end loop;
      return To_String (Result);
   end Package_Aliases;
