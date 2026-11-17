separate (Check_All)
   procedure Check_Ascii_Lowercasing is
      --  Ada.Characters.Handling's To_Lower and To_Upper map Latin-1 bytes,
      --  so on UTF-8 they corrupt a lead byte (0xC3 "Ä" becomes 0xE3). src
      --  case-maps with Files.Types.To_Lower_Ascii / To_Upper_Ascii or folds
      --  with Fold_Case. Read as tokens, so a call split over lines, a use
      --  clause with a bare name, or a renaming of the package are all seen;
      --  Ada.Wide_Wide_Characters.Handling (full Unicode) stays allowed.

      use type Tokens.Token_Kind;

      procedure Check_File (Path : String) is
         Toks : constant Tokens.Token_List :=
           Tokens.Tokens_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         Last : constant Natural := Toks.Last_Index;

         function Word_At (Index : Integer; Text : String) return Boolean is
           (Index in 1 .. Last and then Tokens.Is_Word (Toks (Index), Text));

         function Symbol_At (Index : Integer; Text : String) return Boolean is
           (Index in 1 .. Last and then Tokens.Is_Symbol (Toks (Index), Text));

         function Dot_At (Index : Integer) return Boolean is (Symbol_At (Index, "."));

         --  "handling" at Index names Ada.Characters.Handling: written bare
         --  (after "use Ada.Characters") or after "characters.", never after
         --  "wide_characters." or "wide_wide_characters.".
         function Narrow_Handling_At (Index : Positive) return Boolean is
           (Word_At (Index, "handling")
            and then (not Dot_At (Index - 1) or else Word_At (Index - 2, "characters")));

         procedure Flag (Index : Positive; What : String) is
         begin
            Report
              (Path & ":" & Ada.Strings.Fixed.Trim (Positive'Image (Toks (Index).Line), Ada.Strings.Left)
               & ": " & What & " -- Ada.Characters.Handling case-maps Latin-1 bytes and corrupts UTF-8; use "
               & "Files.Types.To_Lower_Ascii / To_Upper_Ascii, or Fold_Case for text a person reads");
         end Flag;

         Uses_Handling : Boolean := False;
      begin
         for Index in 1 .. Last loop
            --  A name through the package: [Ada.][Characters.]Handling.To_Lower.
            if Narrow_Handling_At (Index)
              and then Dot_At (Index + 1)
              and then (Word_At (Index + 2, "to_lower") or else Word_At (Index + 2, "to_upper"))
            then
               Flag (Index, "Ada.Characters.Handling." & To_String (Toks (Index + 2).Text));
            end if;

            --  "use [Ada.][Characters.]Handling" (not "use type"): every bare
            --  To_Lower / To_Upper below may then be the Latin-1 one.
            if Word_At (Index, "use") and then not Word_At (Index + 1, "type")
              and then not Word_At (Index + 1, "all")
            then
               declare
                  Name_Last : constant Positive :=
                    (if Index < Last then Tokens.Past_Name_Prefix (Toks, Index + 1) else Index);
               begin
                  if Name_Last > Index and then Narrow_Handling_At (Name_Last) then
                     Uses_Handling := True;
                     Flag (Index, "a use clause for Ada.Characters.Handling");
                  end if;
               end;
            end if;

            --  "renames Ada.Characters[.Handling]": a second name for the
            --  package would hide the calls from the rule above.
            if Word_At (Index, "renames")
              and then Word_At (Index + 1, "ada") and then Dot_At (Index + 2)
              and then Word_At (Index + 3, "characters")
              and then (Symbol_At (Index + 4, ";")
                        or else (Dot_At (Index + 4) and then Word_At (Index + 5, "handling")
                                 and then Symbol_At (Index + 6, ";")))
            then
               Flag (Index, "a renaming of Ada.Characters or Ada.Characters.Handling");
            end if;
         end loop;

         if Uses_Handling then
            for Index in 1 .. Last loop
               if (Word_At (Index, "to_lower") or else Word_At (Index, "to_upper"))
                 and then not Dot_At (Index - 1)
                 and then Toks (Index).Kind = Tokens.Word
               then
                  Flag (Index, "a bare " & To_String (Toks (Index).Text) & " under a use of Ada.Characters.Handling");
               end if;
            end loop;
         end if;
      end Check_File;
   begin
      For_Each_Ada_Source (Root & "/src", Check_File'Access);
   end Check_Ascii_Lowercasing;
