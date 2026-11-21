separate (Check_All)
   procedure Check_Test_Stage_Removal is
      use Tokens;

      --  Tests that remove a stage from outside on purpose: the test file and
      --  the name the stage is held in. Each must still do so -- a stale
      --  entry would let a new removal through unreviewed.
      type Exemption is record
         File : Unbounded_String;
         Name : Unbounded_String;
      end record;

      type Exemption_List is array (Positive range <>) of Exemption;

      --  What the foreground cleanup does with a stage that something else
      --  removed is what this test is about.
      Exemptions : constant Exemption_List :=
        [1 => (File => To_Unbounded_String ("files_suite-recovery-test_foreground_forgets_removed_stage.adb"),
               Name => To_Unbounded_String ("first"))];

      procedure Refuse (Message : String) is
      begin
         Report (Message);
      end Refuse;

      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

      --  The names a source holds a Files.Jobs.Context.Create_Stage result in:
      --  "Stage : constant String := ...Create_Stage (...)", or
      --  "Stage := To_Unbounded_String (...Create_Stage (...))".
      function Stage_Names (Toks : Token_List) return Name_Sets.Set is
         Result : Name_Sets.Set;
      begin
         for Call in Toks.First_Index + 4 .. Toks.Last_Index loop
            if Is_Word (Toks (Call), "create_stage")
              and then Is_Symbol (Toks (Call - 1), ".")
              and then Is_Word (Toks (Call - 2), "context")
              and then Is_Symbol (Toks (Call - 3), ".")
              and then Is_Word (Toks (Call - 4), "jobs")
            then
               declare
                  Colon  : Natural := 0;
                  Assign : Natural := 0;
                  Back   : Natural := Call - 1;
               begin
                  --  Back to the start of the statement or declaration.
                  while Back >= Toks.First_Index
                    and then not Is_Symbol (Toks (Back), ";")
                    and then not Is_Word (Toks (Back), "begin")
                    and then not Is_Word (Toks (Back), "is")
                    and then not Is_Word (Toks (Back), "declare")
                    and then not Is_Word (Toks (Back), "then")
                    and then not Is_Word (Toks (Back), "else")
                    and then not Is_Word (Toks (Back), "loop")
                  loop
                     if Is_Symbol (Toks (Back), ":") then
                        Colon := Back;
                     elsif Is_Symbol (Toks (Back), ":=") and then Assign = 0 then
                        Assign := Back;
                     end if;
                     Back := Back - 1;
                  end loop;
                  if Colon > Toks.First_Index and then Toks (Colon - 1).Kind = Word then
                     Result.Include (To_String (Toks (Colon - 1).Text));
                  elsif Assign > Toks.First_Index and then Toks (Assign - 1).Kind = Word then
                     Result.Include (To_String (Toks (Assign - 1).Text));
                  end if;
               end;
            end if;
         end loop;
         return Result;
      end Stage_Names;

      --  The name, or "", of the stage removed by the first Delete_Tree or
      --  Delete_Permanently of Toks whose argument is a stage itself: a
      --  Create_Stage call, or one of Names, bare or through To_String.
      --  Exempt is a name of Names that may be removed so.
      procedure Find_Removal
        (Toks    : Token_List;
         Names   : Name_Sets.Set;
         Exempt  : String;
         Removed : out Unbounded_String;
         Line    : out Natural;
         Excused : out Boolean)
      is
      begin
         Removed := Null_Unbounded_String;
         Line := 0;
         Excused := False;
         for Call in Toks.First_Index .. Toks.Last_Index - 1 loop
            if (Is_Word (Toks (Call), "delete_tree") or else Is_Word (Toks (Call), "delete_permanently"))
              and then Is_Symbol (Toks (Call + 1), "(")
            then
               declare
                  Stop     : constant Positive := Past_Parentheses (Toks, Call + 1);
                  Depth    : Natural := 0;
                  Words    : Natural := 0;
                  Last     : Unbounded_String;
                  Creates  : Boolean := False;
               begin
                  --  The first argument's names, but for prefixes and To_String.
                  for Index in Call + 2 .. Stop - 2 loop
                     exit when Depth = 0 and then Is_Symbol (Toks (Index), ",");
                     if Is_Symbol (Toks (Index), "(") then
                        Depth := Depth + 1;
                     elsif Is_Symbol (Toks (Index), ")") then
                        Depth := Depth - 1;
                     elsif Is_Word (Toks (Index), "create_stage") then
                        Creates := True;
                     elsif Toks (Index).Kind = Word
                       and then not Is_Word (Toks (Index), "to_string")
                       and then not (Index < Toks.Last_Index and then Is_Symbol (Toks (Index + 1), "."))
                     then
                        Words := Words + 1;
                        Last := Toks (Index).Text;
                     end if;
                  end loop;
                  if Creates then
                     Removed := To_Unbounded_String ("create_stage");
                     Line := Toks (Call).Line;
                     return;
                  elsif Words = 1 and then Names.Contains (To_String (Last)) then
                     if To_String (Last) = Exempt then
                        Excused := True;
                     else
                        Removed := Last;
                        Line := Toks (Call).Line;
                        return;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end Find_Removal;

      --  What is wrong with Toks, the source File, or "".
      function Problem (Toks : Token_List; File : String) return String is
         Exempt  : Unbounded_String;
         Removed : Unbounded_String;
         Line    : Natural;
         Excused : Boolean;
      begin
         for Item of Exemptions loop
            if To_String (Item.File) = File then
               Exempt := Item.Name;
            end if;
         end loop;
         Find_Removal (Toks, Stage_Names (Toks), To_String (Exempt), Removed, Line, Excused);
         if Removed /= Null_Unbounded_String then
            return "line" & Line'Image & ": a stage made by Files.Jobs.Context.Create_Stage ("
              & To_String (Removed) & ") is deleted directly; remove it with Files.Jobs.Context.Discard_Stage,"
              & " which drops its record too";
         elsif Exempt /= Null_Unbounded_String and then not Excused then
            return "is exempt from check_all's Check_Test_Stage_Removal for removing the stage "
              & To_String (Exempt) & " from outside, but no longer does; drop the exemption";
         end if;
         return "";
      end Problem;

      type Sample is record
         Text    : Unbounded_String;
         Flagged : Boolean;
      end record;

      function Make (Text : String; Flagged : Boolean) return Sample is
        (Text => To_Unbounded_String (Text), Flagged => Flagged);

      type Sample_List is array (Positive range <>) of Sample;

      LF : constant Character := ASCII.LF;

      Samples : constant Sample_List :=
        [Make ("Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));" & LF
               & "Removed := Files.File_System.Delete_Permanently (To_String (Stage));",
               Flagged => True),
         Make ("declare" & LF & "   Stage : constant String := Files.Jobs.Context.Create_Stage (Parent);" & LF
               & "begin" & LF & "   Project_Tools.Files.Delete_Tree (Stage);" & LF & "end;",
               Flagged => True),
         Make ("Ada.Directories.Delete_Tree (Files.Jobs.Context.Create_Stage (Root));",
               Flagged => True),
         Make ("Stage := To_Unbounded_String (Files.Jobs.Context.Create_Stage (Root));" & LF
               & "Assert (Files.Jobs.Context.Discard_Stage (To_String (Stage)), ""discarded"");" & LF
               & "Removed := Files.File_System.Delete_Permanently (Join (To_String (Stage), ""child""));" & LF
               & "Removed := Files.File_System.Delete_Permanently (Other);",
               Flagged => False)];
   begin
      for Index in Samples'Range loop
         if (Problem (Tokens_Of (To_String (Samples (Index).Text)), "sample") /= "") /= Samples (Index).Flagged then
            Refuse
              ("check_all's Check_Test_Stage_Removal no longer tells its sample" & Natural'Image (Index)
               & (if Samples (Index).Flagged then " from a discarded stage" else " from a deleted one"));
         end if;
      end loop;

      for Source of Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "*.adb", Generated_Directories) loop
         declare
            Path  : constant String := To_String (Source);
            Found : constant String :=
              Problem (Tokens_Of (Project_Tools.Files.Read_Raw_File (Path)), Ada.Directories.Simple_Name (Path));
         begin
            if Found /= "" then
               Refuse (Path & ": " & Found);
            end if;
         end;
      end loop;
      for Item of Exemptions loop
         if not Project_Tools.Files.File_Exists (Root & "/tests/tests/src/" & To_String (Item.File)) then
            Refuse
              ("check_all's Check_Test_Stage_Removal exempts " & To_String (Item.File) & ", which is missing");
         end if;
      end loop;
   end Check_Test_Stage_Removal;
