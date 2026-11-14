with Ada.Containers.Indefinite_Hashed_Maps;
separate (Check_All)
   procedure Check_Test_Hooks is
      use Tokens;

      --  Names are compared in lower case, in code with its comments
      --  dropped: Windows looks environment variables up regardless of case
      --  (Files_Test_X reads FILES_TEST_X there), and a name in a comment
      --  reads nothing.
      Hook_Prefix   : constant String := "files_test_";
      Override      : constant String := "files_trash_backend";
      Override_Text : constant String := "FILES_TRASH_BACKEND";
      Hooks : constant Project_Tools.Files.Path_List :=
        [To_Unbounded_String (Root & "/src/files-file_system-support.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_supported.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_bases.adb")];
      Override_Home : constant String := Root & "/src/files-file_system-trash_location_for_environment.adb";
      Override_Homes : constant Project_Tools.Files.Path_List := [1 => To_Unbounded_String (Override_Home)];

      --  Where a qualification ending at From starts its operand: past
      --  "string'" or "standard.string'" (any name, dotted, then a tick)
      --  when a "(" follows; From itself otherwise.
      function Past_Qualifier (Toks : Token_List; From : Positive) return Positive is
         Next : Positive := From;
      begin
         while Next + 1 <= Toks.Last_Index
           and then Toks (Next).Kind = Word
           and then Is_Symbol (Toks (Next + 1), ".")
         loop
            Next := Next + 2;
         end loop;
         if Next + 2 <= Toks.Last_Index
           and then Toks (Next).Kind = Word
           and then Is_Symbol (Toks (Next + 1), "'")
           and then Is_Symbol (Toks (Next + 2), "(")
         then
            return Next + 2;
         end if;
         return From;
      end Past_Qualifier;

      --  Past every "(" and qualification from From on.
      function Past_Openers (Toks : Token_List; From : Positive) return Positive is
         Next : Positive := From;
      begin
         loop
            if Next <= Toks.Last_Index and then Is_Symbol (Toks (Next), "(") then
               Next := Next + 1;
            elsif Next <= Toks.Last_Index and then Past_Qualifier (Toks, Next) /= Next then
               Next := Past_Qualifier (Toks, Next);
            else
               return Next;
            end if;
         end loop;
      end Past_Openers;

      --  The literal value every known string name stands for: one a unit
      --  declares, keyed by the unit's path, a NUL and the name; any unit's,
      --  keyed by the name (the first unit to declare a name gives it).
      package Value_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type => String, Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");

      type Names is record
         Locals : Value_Maps.Map;
         Global : Value_Maps.Map;
      end record;

      function Local_Key (Path, Name : String) return String is (Path & ASCII.NUL & Name);

      --  Toks with every known string name spelled as its literal: the
      --  unit's own declaration first, then any unit's. A name followed by
      --  "." or after a tick is a prefix or an attribute, not a value; a
      --  qualified name (Files.Hooks.Prefix) is replaced whole.
      function Spelled (Toks : Token_List; Path : String; Known : Names) return Token_List is
         Result : Token_List;
      begin
         for Index in Toks.First_Index .. Toks.Last_Index loop
            declare
               Item   : constant Token := Toks (Index);
               Name   : constant String := To_String (Item.Text);
               Prefix : constant Boolean := Index < Toks.Last_Index and then Is_Symbol (Toks (Index + 1), ".");
               Ticked : constant Boolean := Index > Toks.First_Index and then Is_Symbol (Toks (Index - 1), "'");
               Value  : Unbounded_String;
               Found  : Boolean := False;
            begin
               if Item.Kind = Word and then not Prefix and then not Ticked then
                  if Known.Locals.Contains (Local_Key (Path, Name)) then
                     Value := To_Unbounded_String (Known.Locals.Element (Local_Key (Path, Name)));
                     Found := True;
                  elsif Known.Global.Contains (Name) then
                     Value := To_Unbounded_String (Known.Global.Element (Name));
                     Found := True;
                  end if;
               end if;
               if Found then
                  while Natural (Result.Length) >= 2
                    and then Is_Symbol (Result.Last_Element, ".")
                    and then Result (Result.Last_Index - 1).Kind = Word
                  loop
                     Result.Delete_Last (Count => 2);
                  end loop;
                  Result.Append (Token'(Kind => Literal, Text => Value));
               else
                  Result.Append (Item);
               end if;
            end;
         end loop;
         return Result;
      end Spelled;

      --  Toks with every join of literals closed up into one: "a" & "b",
      --  "a" & 'b', ("a") & ("b") and "a" & String'("b") all read "ab". The
      --  parentheses closed on the way are dropped.
      function Collapsed (Toks : Token_List) return Token_List is
         Result : Token_List;
         Index  : Positive := Toks.First_Index;
      begin
         while Index <= Toks.Last_Index loop
            if Toks (Index).Kind = Literal then
               declare
                  Value : Unbounded_String := Toks (Index).Text;
                  Next  : Positive := Index + 1;
                  Scan  : Positive;
               begin
                  loop
                     Scan := Next;
                     while Scan <= Toks.Last_Index and then Is_Symbol (Toks (Scan), ")") loop
                        Scan := Scan + 1;
                     end loop;
                     exit when Scan > Toks.Last_Index or else not Is_Symbol (Toks (Scan), "&");
                     Scan := Past_Openers (Toks, Scan + 1);
                     exit when Scan > Toks.Last_Index or else Toks (Scan).Kind /= Literal;
                     Append (Value, Toks (Scan).Text);
                     Next := Scan + 1;
                  end loop;
                  Result.Append (Token'(Kind => Literal, Text => Value));
                  Index := Next;
               end;
            else
               Result.Append (Toks (Index));
               Index := Index + 1;
            end if;
         end loop;
         return Result;
      end Collapsed;

      --  One unit of source: its path and tokens.
      type Unit is record
         Path : Unbounded_String;
         Toks : Token_List;
      end record;

      package Unit_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Unit);

      --  A string object a unit declares, constant or not: what it is
      --  initialised to, or what it renames.
      type Declaration is record
         Path    : Unbounded_String;
         Name    : Unbounded_String;
         Value   : Token_List;
         Renamed : Unbounded_String;
         Known   : Boolean := False;
      end record;

      package Declaration_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Declaration);

      --  Every string object Source declares, in any form:
      --  "X : constant String := ...", "X : aliased constant String := ...",
      --  "X : String (1 .. 8) := ..." (a variable too, by its initial value),
      --  "P, Q : constant String := ...", "X : String renames Y", and any
      --  of these split over lines; String may be named Standard.String.
      procedure Collect (Source : Unit; Into : in out Declaration_Vectors.Vector) is
         Toks : Token_List renames Source.Toks;
      begin
         for Colon in Toks.First_Index .. Toks.Last_Index loop
            if Is_Symbol (Toks (Colon), ":") and then Colon > Toks.First_Index then
               declare
                  First_Name : Positive := Colon - 1;
                  Next       : Positive := Colon + 1;
                  Value      : Token_List;
                  Renamed    : Unbounded_String;
                  Depth      : Natural := 0;
                  Is_String  : Boolean := False;
                  Has_Value  : Boolean := False;
               begin
                  if Toks (First_Name).Kind = Word then
                     --  Back over a list of names: P, Q, R.
                     while First_Name - 2 >= Toks.First_Index
                       and then Is_Symbol (Toks (First_Name - 1), ",")
                       and then Toks (First_Name - 2).Kind = Word
                     loop
                        First_Name := First_Name - 2;
                     end loop;
                     if Next <= Toks.Last_Index and then Is_Word (Toks (Next), "aliased") then
                        Next := Next + 1;
                     end if;
                     if Next <= Toks.Last_Index and then Is_Word (Toks (Next), "constant") then
                        Next := Next + 1;
                     end if;
                     while Next + 1 <= Toks.Last_Index
                       and then Toks (Next).Kind = Word
                       and then Is_Symbol (Toks (Next + 1), ".")
                     loop
                        Next := Next + 2;
                     end loop;
                     if Next <= Toks.Last_Index and then Is_Word (Toks (Next), "string") then
                        Is_String := True;
                        Next := Next + 1;
                     end if;
                     --  A constraint: (1 .. 8).
                     if Is_String and then Next <= Toks.Last_Index and then Is_Symbol (Toks (Next), "(") then
                        loop
                           exit when Next > Toks.Last_Index;
                           if Is_Symbol (Toks (Next), "(") then
                              Depth := Depth + 1;
                           elsif Is_Symbol (Toks (Next), ")") then
                              Depth := Depth - 1;
                           end if;
                           Next := Next + 1;
                           exit when Depth = 0;
                        end loop;
                     end if;
                     if Is_String and then Next <= Toks.Last_Index and then Is_Symbol (Toks (Next), ":=") then
                        --  The value, to the ";" (or the ")" that closes a
                        --  parameter list) at its own depth.
                        Next := Next + 1;
                        Depth := 0;
                        while Next <= Toks.Last_Index
                          and then not Is_Symbol (Toks (Next), ";")
                          and then not (Depth = 0 and then Is_Symbol (Toks (Next), ")"))
                        loop
                           if Is_Symbol (Toks (Next), "(") then
                              Depth := Depth + 1;
                           elsif Is_Symbol (Toks (Next), ")") then
                              Depth := Depth - 1;
                           end if;
                           Value.Append (Toks (Next));
                           Next := Next + 1;
                        end loop;
                        Has_Value := True;
                     elsif Is_String and then Next <= Toks.Last_Index and then Is_Word (Toks (Next), "renames") then
                        Next := Next + 1;
                        while Next + 1 <= Toks.Last_Index
                          and then Toks (Next).Kind = Word
                          and then Is_Symbol (Toks (Next + 1), ".")
                        loop
                           Next := Next + 2;
                        end loop;
                        if Next <= Toks.Last_Index and then Toks (Next).Kind = Word then
                           Renamed := Toks (Next).Text;
                           Has_Value := True;
                        end if;
                     end if;
                     if Has_Value then
                        for Name_At in First_Name .. Colon - 1 loop
                           if Toks (Name_At).Kind = Word then
                              Into.Append
                                (Declaration'
                                   (Path    => Source.Path,
                                    Name    => Toks (Name_At).Text,
                                    Value   => Value,
                                    Renamed => Renamed,
                                    Known   => False));
                           end if;
                        end loop;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end Collect;

      --  The literal Toks stand for once spelled and joined: one literal,
      --  with nothing around it but parentheses and qualifications.
      procedure Evaluate
        (Toks  : Token_List;
         Path  : String;
         Known : Names;
         Found : out Boolean;
         Value : out Unbounded_String)
      is
         Joined : constant Token_List := Collapsed (Spelled (Toks, Path, Known));
         Index  : Positive := Joined.First_Index;
         Count  : Natural := 0;
      begin
         Found := False;
         Value := Null_Unbounded_String;
         while Index <= Joined.Last_Index loop
            if Is_Symbol (Joined (Index), "(") or else Is_Symbol (Joined (Index), ")") then
               Index := Index + 1;
            elsif Past_Qualifier (Joined, Index) /= Index then
               Index := Past_Qualifier (Joined, Index);
            elsif Joined (Index).Kind = Literal then
               Count := Count + 1;
               Value := Joined (Index).Text;
               Index := Index + 1;
            else
               return;
            end if;
         end loop;
         Found := Count = 1;
      end Evaluate;

      --  Every string name the units declare that stands for one literal,
      --  resolved until nothing more resolves: a name built from another
      --  (in any unit, declared before or after it) resolves too.
      function Resolve (Units : Unit_Vectors.Vector) return Names is
         Declarations : Declaration_Vectors.Vector;
         Result       : Names;
         Progress     : Boolean;
      begin
         for Source of Units loop
            Collect (Source, Declarations);
         end loop;
         loop
            Progress := False;
            for Item of Declarations loop
               if not Item.Known then
                  declare
                     Path  : constant String := To_String (Item.Path);
                     Name  : constant String := To_String (Item.Name);
                     Found : Boolean := False;
                     Value : Unbounded_String;
                  begin
                     if Item.Renamed /= Null_Unbounded_String then
                        if Result.Locals.Contains (Local_Key (Path, To_String (Item.Renamed))) then
                           Value := To_Unbounded_String
                             (Result.Locals.Element (Local_Key (Path, To_String (Item.Renamed))));
                           Found := True;
                        elsif Result.Global.Contains (To_String (Item.Renamed)) then
                           Value := To_Unbounded_String (Result.Global.Element (To_String (Item.Renamed)));
                           Found := True;
                        end if;
                     else
                        Evaluate (Item.Value, Path, Result, Found, Value);
                     end if;
                     if Found then
                        Item.Known := True;
                        Progress := True;
                        if not Result.Locals.Contains (Local_Key (Path, Name)) then
                           Result.Locals.Insert (Local_Key (Path, Name), To_String (Value));
                        end if;
                        if not Result.Global.Contains (Name) then
                           Result.Global.Insert (Name, To_String (Value));
                        end if;
                     end if;
                  end;
               end if;
            end loop;
            exit when not Progress;
         end loop;
         return Result;
      end Resolve;

      --  The unit's code as text, every known string name spelled as its
      --  literal and every join closed up, so a name built in pieces reads
      --  whole.
      function Resolved_Text (Source : Unit; Known : Names) return String is
         Result : Unbounded_String;
      begin
         for Item of Collapsed (Spelled (Source.Toks, To_String (Source.Path), Known)) loop
            if Item.Kind = Literal then
               Append (Result, '"' & To_String (Item.Text) & """ ");
            else
               Append (Result, To_String (Item.Text) & " ");
            end if;
         end loop;
         return To_String (Result);
      end Resolved_Text;

      --  Whether the unit joins something to a literal ending in "files_"
      --  (spelled and joined as far as it resolves): a variable name built
      --  in pieces the resolution cannot see through.
      function Splits_Prefix (Source : Unit; Known : Names) return Boolean is
         Toks : constant Token_List := Collapsed (Spelled (Source.Toks, To_String (Source.Path), Known));
      begin
         for Index in Toks.First_Index .. Toks.Last_Index loop
            if Toks (Index).Kind = Literal
              and then Ada.Strings.Fixed.Tail (To_String (Toks (Index).Text), 6) = "files_"
            then
               declare
                  Next : Positive := Index + 1;
               begin
                  while Next <= Toks.Last_Index and then Is_Symbol (Toks (Next), ")") loop
                     Next := Next + 1;
                  end loop;
                  if Next <= Toks.Last_Index and then Is_Symbol (Toks (Next), "&") then
                     return True;
                  end if;
               end;
            end if;
         end loop;
         return False;
      end Splits_Prefix;

      function Contains (Text, Pattern : String) return Boolean is
        (Ada.Strings.Fixed.Index (Text, Pattern) > 0);

      function Listed (Path : String; Allowed : Project_Tools.Files.Path_List) return Boolean is
        (for some Item of Allowed => To_String (Item) = Path);

      procedure Refuse (Message : String) is
      begin
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      --  The resolution itself, on every shape it exists for: if it stopped
      --  seeing one, the tree search below would pass on every source.
      --  Other is a second unit the sample's Text may name constants of.
      type Sample is record
         Other : Unbounded_String;
         Text  : Unbounded_String;
         Name  : Unbounded_String;
      end record;

      function Make (Text : String; Name : String := Hook_Prefix; Other : String := "") return Sample is
        (Other => To_Unbounded_String (Other), Text => To_Unbounded_String (Text), Name => To_Unbounded_String (Name));

      type Sample_List is array (Positive range <>) of Sample;

      LF : constant Character := ASCII.LF;

      Samples : constant Sample_List :=
        [Make ("X : constant String := Value (""FILES_TE"" & ""ST_X"");"),
         Make ("Prefix : constant String := ""FILES_TE"";" & LF & "X : constant String := Value (prefix & ""ST_X"");"),
         Make ("Start  : constant String := ""FILES_"";" & LF
               & "Middle : constant String := Start & ""TRASH_"";" & LF
               & "X : constant String := Value (Middle & ""BACKEND"");",
               Name => Override),
         Make ("Prefix : aliased constant String := ""FILES_TE"";" & LF & "X : Boolean := Is_Set (Prefix & ""ST_X"");"),
         Make ("Prefix : constant String (1 .. 8) := ""FILES_TE"";" & LF
               & "X : Boolean := Is_Set (Prefix & ""ST_X"");"),
         Make ("Prefix" & LF & "  :" & LF & "  constant" & LF & "  String" & LF & "  :=" & LF & "  ""FILES_TE"";" & LF
               & "X : Boolean := Is_Set (Prefix & ""ST_X"");"),
         Make ("Prefix : String := ""FILES_TE"";" & LF & "X : Boolean := Is_Set (Prefix & ""ST_X"");"),
         Make ("P, Q : constant String := ""FILES_TE"";" & LF & "X : Boolean := Is_Set (Q & ""ST_X"");"),
         Make ("Base : constant String := ""FILES_TE"";" & LF & "Prefix : String renames Base;" & LF
               & "X : Boolean := Is_Set (Prefix & ""ST_X"");"),
         Make ("X : Boolean := Is_Set (Hook_Names.Prefix & ""ST_X"");",
               Other => "package Hook_Names is" & LF & "   Prefix : constant String := ""FILES_TE"";" & LF
                        & "end Hook_Names;"),
         Make ("X : Boolean := Is_Set (""FILES_TES"" & 'T' & ""_X"");"),
         Make ("X : Boolean := Is_Set ((""FILES_TE"") & (""ST_X""));"),
         Make ("X : Boolean := Is_Set (""FILES_TE"" & String'(""ST_X""));"),
         Make ("X : Boolean := Is_Set (""FILES_TE"" &" & LF & "  --  the rest" & LF & "  ""ST_X"");"),
         Make ("X : Boolean := Is_Set (""Files_Test_X"");")];

      function Sample_Finds (Item : Sample) return Boolean is
         Units : Unit_Vectors.Vector;
      begin
         if Item.Other /= Null_Unbounded_String then
            Units.Append (Unit'(Path => To_Unbounded_String ("other"), Toks => Tokens_Of (To_String (Item.Other))));
         end if;
         Units.Append (Unit'(Path => To_Unbounded_String ("sample"), Toks => Tokens_Of (To_String (Item.Text))));
         return Contains (Resolved_Text (Units.Last_Element, Resolve (Units)), To_String (Item.Name));
      end Sample_Finds;

      Units : Unit_Vectors.Vector;
   begin
      for Index in Samples'Range loop
         if not Sample_Finds (Samples (Index)) then
            Refuse ("check_all's Check_Test_Hooks no longer sees the name built in its sample" & Natural'Image (Index));
         end if;
      end loop;
      if not Splits_Prefix
        (Unit'(Path => To_Unbounded_String ("sample"), Toks => Tokens_Of ("X : String := Value (""Files_"" & Y);")),
         (others => <>))
      then
         Refuse ("check_all's Check_Test_Hooks no longer sees a FILES_ prefix joined to an unknown part");
      end if;

      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         Units.Append (Unit'(Path => Item, Toks => Tokens_Of (Project_Tools.Files.Read_Raw_File (To_String (Item)))));
      end loop;

      declare
         Known : constant Names := Resolve (Units);
      begin
         for Source of Units loop
            declare
               Path : constant String := To_String (Source.Path);
               Code : constant String :=
                 Ada.Characters.Handling.To_Lower (Code_Of (Project_Tools.Files.Read_Raw_File (Path)));
               Text : constant String := Resolved_Text (Source, Known);
            begin
               if not Listed (Path, Hooks) then
                  if Contains (Code, Hook_Prefix) then
                     Refuse (Path & ": reads a FILES_TEST_* variable outside the listed test hooks");
                  elsif Contains (Text, Hook_Prefix) then
                     Refuse (Path & ": builds a FILES_TEST_ variable name from joined literals or string constants");
                  elsif Splits_Prefix (Source, Known) then
                     Refuse (Path & ": builds a FILES_ variable name in pieces; spell it whole");
                  end if;
               elsif not Contains (Text, Hook_Prefix) then
                  --  A stale entry would let a new hook into that file pass
                  --  unreviewed.
                  Refuse (Path & " is listed as a test hook but reads none");
               end if;
               if Listed (Path, Override_Homes) then
                  if not Contains (Text, Override) then
                     Refuse (Path & " is the one reader of " & Override_Text & " but reads it no more");
                  end if;
               elsif Contains (Text, Override) then
                  Refuse
                    (Path & ": reads " & Override_Text & ", which forces another host's trash backend; only "
                     & Override_Home & " may read it");
               end if;
            end;
         end loop;
      end;
      --  A listed file that is gone reads nothing either.
      for Hook of Hooks loop
         if not Project_Tools.Files.File_Exists (To_String (Hook)) then
            Refuse (To_String (Hook) & " is listed as a test hook but is missing");
         end if;
      end loop;
      if not Project_Tools.Files.File_Exists (Override_Home) then
         Refuse (Override_Home & " is the one reader of " & Override_Text & " but is missing");
      end if;
   end Check_Test_Hooks;
