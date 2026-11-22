separate (Check_All)
   procedure Check_Test_Link_Routing is
      use Tokens;

      procedure Refuse (Message : String) is
      begin
         Report (Message);
      end Refuse;

      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

      type Depth_List is array (Positive range <>) of Natural;

      function Word_At (Toks : Token_List; Index : Integer; Text : String) return Boolean is
        (Index in Toks.First_Index .. Toks.Last_Index and then Is_Word (Toks (Index), Text));

      function Symbol_At (Toks : Token_List; Index : Integer; Text : String) return Boolean is
        (Index in Toks.First_Index .. Toks.Last_Index and then Is_Symbol (Toks (Index), Text));

      --  Whether Toks (Index) calls a link maker the host may refuse:
      --  Hostkit.Fs.Create_Link or Create_Hard_Link, or the suite's
      --  Create_Symlink (Files_Suite.Support.Disk's, named bare or in full).
      function Makes_Link (Toks : Token_List; Index : Positive) return Boolean is
        (Symbol_At (Toks, Index + 1, "(")
         and then
           (((Word_At (Toks, Index, "create_link") or else Word_At (Toks, Index, "create_hard_link"))
             and then Symbol_At (Toks, Index - 1, ".") and then Word_At (Toks, Index - 2, "fs")
             and then Symbol_At (Toks, Index - 3, ".") and then Word_At (Toks, Index - 4, "hostkit"))
            or else
              (Word_At (Toks, Index, "create_symlink")
               and then (not Symbol_At (Toks, Index - 1, ".")
                         or else (Word_At (Toks, Index - 2, "disk") and then Symbol_At (Toks, Index - 3, "."))))));

      --  Whether Toks (Index) says the link was not made: Link_Not_Made, or a
      --  Skip of Files_Suite.Support with its own reason.
      function Routes (Toks : Token_List; Index : Positive) return Boolean is
        (Word_At (Toks, Index, "link_not_made")
         or else (Word_At (Toks, Index, "skip") and then Symbol_At (Toks, Index - 1, ".")
                  and then Word_At (Toks, Index - 2, "support")));

      function Routed_Between (Toks : Token_List; First, Last : Natural) return Boolean is
      begin
         for Index in First .. Natural'Min (Last, Toks.Last_Index) loop
            if Routes (Toks, Index) then
               return True;
            end if;
         end loop;
         return False;
      end Routed_Between;

      --  How deep in parentheses each token is: a statement's own keywords
      --  are at depth 0; an if expression's are not.
      function Depths (Toks : Token_List) return Depth_List is
         Result : Depth_List (Toks.First_Index .. Natural'Max (Toks.Last_Index, Toks.First_Index));
         Depth  : Natural := 0;
      begin
         for Index in Toks.First_Index .. Toks.Last_Index loop
            if Is_Symbol (Toks (Index), ")") and then Depth > 0 then
               Depth := Depth - 1;
            end if;
            Result (Index) := Depth;
            if Is_Symbol (Toks (Index), "(") then
               Depth := Depth + 1;
            end if;
         end loop;
         return Result;
      end Depths;

      --  An if statement's own "if" (not "end if", not an if expression).
      function Opens_If (Toks : Token_List; Depth : Depth_List; Index : Positive) return Boolean is
        (Word_At (Toks, Index, "if") and then Depth (Index) = 0 and then not Word_At (Toks, Index - 1, "end"));

      function Closes_If (Toks : Token_List; Depth : Depth_List; Index : Positive) return Boolean is
        (Word_At (Toks, Index, "end") and then Word_At (Toks, Index + 1, "if") and then Depth (Index) = 0);

      --  The "end" of the "end if" closing the if statement opened at Index.
      function End_Of_If (Toks : Token_List; Depth : Depth_List; Index : Positive) return Natural is
         Open : Natural := 0;
      begin
         for Here in Index .. Toks.Last_Index loop
            if Opens_If (Toks, Depth, Here) then
               Open := Open + 1;
            elsif Closes_If (Toks, Depth, Here) then
               Open := Open - 1;
               if Open = 0 then
                  return Here;
               end if;
            end if;
         end loop;
         return Toks.Last_Index;
      end End_Of_If;

      --  The "if" opening the if statement an "elsif" at Index belongs to.
      function If_Of_Elsif (Toks : Token_List; Depth : Depth_List; Index : Positive) return Positive is
         Closed : Natural := 0;
      begin
         for Here in reverse Toks.First_Index .. Index - 1 loop
            if Closes_If (Toks, Depth, Here) then
               Closed := Closed + 1;
            elsif Opens_If (Toks, Depth, Here) then
               if Closed = 0 then
                  return Here;
               end if;
               Closed := Closed - 1;
            end if;
         end loop;
         return Index;
      end If_Of_Elsif;

      --  Whether Toks (Index) ends one statement or a condition (the "then"
      --  of "and then" and the "else" of "or else" do not).
      function Ends_Statement (Toks : Token_List; Depth : Depth_List; Index : Positive) return Boolean is
        (Depth (Index) = 0
         and then (Is_Symbol (Toks (Index), ";") or else Is_Symbol (Toks (Index), "=>")
                   or else Is_Word (Toks (Index), "begin") or else Is_Word (Toks (Index), "is")
                   or else Is_Word (Toks (Index), "declare") or else Is_Word (Toks (Index), "loop")
                   or else (Is_Word (Toks (Index), "then") and then not Word_At (Toks, Index - 1, "and"))
                   or else (Is_Word (Toks (Index), "else") and then not Word_At (Toks, Index - 1, "or"))));

      --  The "then" ending the condition of the if or elsif at Index.
      function Then_Of (Toks : Token_List; Depth : Depth_List; Index : Positive) return Positive is
      begin
         for Here in Index + 1 .. Toks.Last_Index loop
            if Depth (Here) = 0 and then Is_Word (Toks (Here), "then") and then not Word_At (Toks, Here - 1, "and")
            then
               return Here;
            end if;
         end loop;
         return Toks.Last_Index;
      end Then_Of;

      --  Whether the result held in Name (or passed on from it by a later
      --  assignment) reaches a later if whose branches say the link was not
      --  made.
      function Name_Routed (Toks : Token_List; Depth : Depth_List; Name : String; From : Positive) return Boolean
      is
         Names   : Name_Sets.Set;
         Changed : Boolean := True;
      begin
         Names.Include (Name);
         while Changed loop
            Changed := False;
            for Here in From .. Toks.Last_Index loop
               if Is_Symbol (Toks (Here), ":=") and then Here > Toks.First_Index
                 and then Toks (Here - 1).Kind = Word
                 and then not Names.Contains (To_String (Toks (Here - 1).Text))
               then
                  declare
                     Stop : Positive := Here;
                  begin
                     while Stop < Toks.Last_Index and then not Is_Symbol (Toks (Stop), ";") loop
                        Stop := Stop + 1;
                     end loop;
                     for Inside in Here + 1 .. Stop loop
                        if Toks (Inside).Kind = Word and then Names.Contains (To_String (Toks (Inside).Text)) then
                           Names.Include (To_String (Toks (Here - 1).Text));
                           Changed := True;
                           exit;
                        end if;
                     end loop;
                  end;
               end if;
            end loop;
         end loop;
         for Here in From .. Toks.Last_Index loop
            if Opens_If (Toks, Depth, Here) or else (Word_At (Toks, Here, "elsif") and then Depth (Here) = 0) then
               declare
                  Condition_End : constant Positive := Then_Of (Toks, Depth, Here);
                  Opening       : constant Positive :=
                    (if Word_At (Toks, Here, "elsif") then If_Of_Elsif (Toks, Depth, Here) else Here);
               begin
                  for Inside in Here + 1 .. Condition_End loop
                     if Toks (Inside).Kind = Word and then Names.Contains (To_String (Toks (Inside).Text))
                       and then Routed_Between (Toks, Condition_End, End_Of_If (Toks, Depth, Opening))
                     then
                        return True;
                     end if;
                  end loop;
               end;
            end if;
         end loop;
         return False;
      end Name_Routed;

      --  The line of the first link made in Toks whose failure no test
      --  reports, or 0. A link made in an if condition is reported by a
      --  Link_Not_Made (or a Skip) in that if statement; one whose result is
      --  held in a name, by one in a later if on that name; any other one
      --  (an Assert of it, a result dropped) is not reported at all.
      function Unrouted_Line (Toks : Token_List) return Natural is
         Depth : constant Depth_List := Depths (Toks);
      begin
         for Call in Toks.First_Index .. Toks.Last_Index loop
            if Makes_Link (Toks, Call) then
               declare
                  Start  : Natural := Call - 1;
                  Assign : Natural := 0;
                  Ok     : Boolean := False;
               begin
                  while Start >= Toks.First_Index and then not Ends_Statement (Toks, Depth, Start) loop
                     if Depth (Start) = 0 and then Is_Symbol (Toks (Start), ":=") then
                        Assign := Start;
                     end if;
                     Start := Start - 1;
                  end loop;
                  Start := Start + 1;
                  if Opens_If (Toks, Depth, Start) then
                     Ok := Routed_Between (Toks, Call, End_Of_If (Toks, Depth, Start));
                  elsif Word_At (Toks, Start, "elsif") then
                     Ok := Routed_Between (Toks, Call, End_Of_If (Toks, Depth, If_Of_Elsif (Toks, Depth, Start)));
                  elsif Assign /= 0 and then Toks (Start).Kind = Word then
                     --  "Name := ..." or "Name : [constant] Boolean := ...".
                     Ok := Name_Routed (Toks, Depth, To_String (Toks (Start).Text), Call);
                  end if;
                  if not Ok then
                     return Toks (Call).Line;
                  end if;
               end;
            end if;
         end loop;
         return 0;
      end Unrouted_Line;

      type Sample is record
         Text    : Unbounded_String;
         Flagged : Boolean;
      end record;

      function Make (Text : String; Flagged : Boolean) return Sample is
        (Text => To_Unbounded_String (Text), Flagged => Flagged);

      type Sample_List is array (Positive range <>) of Sample;

      LF : constant Character := ASCII.LF;

      Samples : constant Sample_List :=
        [Make ("Assert (Hostkit.Fs.Create_Link (Target, Link), ""made"");", Flagged => True),
         Make ("if Hostkit.Fs.Create_Hard_Link (A, B) then" & LF & "   Check;" & LF & "end if;", Flagged => True),
         Make ("Linked := Create_Symlink (A, B);" & LF & "Assert (not Linked or else Kept, ""kept"");",
               Flagged => True),
         Make ("declare" & LF & "   Made : constant Boolean := Files_Suite.Support.Disk.Create_Symlink (A, B);" & LF
               & "   pragma Unreferenced (Made);" & LF & "begin" & LF & "   null;" & LF & "end;",
               Flagged => True),
         Make ("if Hostkit.Fs.Create_Link (A, B) then" & LF & "   Check ((if X then Y else Z));" & LF
               & "end if;" & LF & "if Other then" & LF & "   Link_Not_Made (""T"");" & LF & "end if;",
               Flagged => True),
         Make ("if not Hostkit.Fs.Create_Link (A, B)" & LF & "  and then Hostkit.Fs.Create_Link (C, D)" & LF
               & "then" & LF & "   Files_Suite.Support.Disk.Link_Not_Made (""T"");" & LF & "   return;" & LF
               & "end if;",
               Flagged => False),
         Make ("if Hostkit.Fs.Create_Link (A, B) then" & LF & "   if X then" & LF & "      Y;" & LF & "   end if;"
               & LF & "else" & LF & "   Link_Not_Made (""T"");" & LF & "end if;",
               Flagged => False),
         Make ("Left := Hostkit.Fs.Create_Link (A, B);" & LF & "Right := Left and then Create_Symlink (C, D);" & LF
               & "if Right then" & LF & "   Check;" & LF & "else" & LF & "   Link_Not_Made (""T"");" & LF
               & "end if;",
               Flagged => False),
         Make ("if Files_Suite.Support.Disk.Create_Symlink (A, B) then" & LF & "   Check;" & LF & "else" & LF
               & "   Files_Suite.Support.Skip (""T"", ""the second volume takes no links"");" & LF & "end if;",
               Flagged => False),
         Make ("Mutation := Files.File_System.Create_Hard_Link (A, B);" & LF
               & "Run (Files.Commands.Create_Symlink_Command);",
               Flagged => False)];
   begin
      for Index in Samples'Range loop
         if (Unrouted_Line (Tokens_Of (To_String (Samples (Index).Text))) /= 0) /= Samples (Index).Flagged then
            Refuse
              ("check_all's Check_Test_Link_Routing no longer tells its sample" & Natural'Image (Index)
               & (if Samples (Index).Flagged then " from a routed link" else " from an unrouted one"));
         end if;
      end loop;

      for Source of
        Project_Tools.Files.List_Tree (Root & "/tests/tests/src", "files_suite-*.adb", Generated_Directories)
      loop
         declare
            Path : constant String := To_String (Source);
            Name : constant String := Ada.Directories.Simple_Name (Path);
         begin
            --  The disk support makes the links the rest ask for.
            if Name /= "files_suite-support-disk.adb" then
               declare
                  Line : constant Natural := Unrouted_Line (Tokens_Of (Project_Tools.Files.Read_Raw_File (Path)));
               begin
                  if Line /= 0 then
                     Refuse
                       (Name & ":" & Ada.Strings.Fixed.Trim (Line'Image, Ada.Strings.Left)
                        & ": a link the host may refuse is made without saying so when it is not:"
                        & " test the result and call Files_Suite.Support.Disk.Link_Not_Made (failing on Linux,"
                        & " skipping elsewhere) in that if statement, or in a later one on the name holding it");
                  end if;
               end;
            end if;
         end;
      end loop;
   end Check_Test_Link_Routing;
