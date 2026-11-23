with Ada.Containers.Indefinite_Hashed_Maps;

separate (Check_All)
   procedure Check_Test_Only_Api is
      use Tokens;

      package File_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type => String, Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");

      --  "unit.subprogram", lower case: CLAUDE.md's exceptions.
      Exempt : constant String :=
        "files.file_types.filetype_for_extension" & ASCII.LF
        & "files.file_types.icon_for_filetype" & ASCII.LF
        & "files.leaf_names.length_under";

      Src     : constant String := Root & "/src";
      Sources : constant Project_Tools.Files.Path_List :=
        Project_Tools.Files.List_Tree (Src, "*.ad?", Generated_Directories);

      --  Every unit in src/, one a line.
      function All_Units return String is
         Result : Unbounded_String;
      begin
         for Item of Sources loop
            declare
               Unit : constant String := Unit_Of_File (To_String (Item));
            begin
               if Ada.Strings.Fixed.Tail (To_String (Item), 4) = ".ads" then
                  Append (Result, Unit & ASCII.LF);
               end if;
            end;
         end loop;
         return To_String (Result);
      end All_Units;

      Units       : constant String := All_Units;
      All_Aliases : constant String := Package_Aliases (Units);

      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      Unit_Set : Name_Sets.Set;

      procedure Add_Unit (Unit : String; Number : Positive) is
         pragma Unreferenced (Number);
      begin
         Unit_Set.Include (Unit);
      end Add_Unit;

      --  Each unit's member a source in src/ resolves to
      --  ("files.commands.contains"), and the simple names of the sources
      --  naming it, one a line. A name counts as named when it is written
      --  qualified (through a package renaming or instance too), made direct
      --  by a use clause, or written bare in a child or subunit of its unit.
      Named_In : File_Maps.Map;
      --  Each unit a type of which another unit derives from, and those
      --  units, one a line: a derived type's inherited operation is called
      --  under the deriving unit's name.
      Derived_In : File_Maps.Map;

      --  Whether Toks (Index) starts a subprogram declaration (not a formal
      --  subprogram, nor an access-to-subprogram type).
      function Declares (Toks : Token_List; Index : Positive) return Boolean is
        ((Is_Word (Toks (Index), "procedure") or else Is_Word (Toks (Index), "function"))
         and then Index < Toks.Last_Index
         and then Toks (Index + 1).Kind = Word
         and then (Index = Toks.First_Index
                   or else not (Is_Word (Toks (Index - 1), "access") or else Is_Word (Toks (Index - 1), "with"))));

      --  Whether the declaration at Index overrides an inherited operation:
      --  it is called by dispatching, under its parent type's name.
      function Overrides (Toks : Token_List; Index : Positive) return Boolean is
        (Index > Toks.First_Index
         and then Is_Word (Toks (Index - 1), "overriding")
         and then not (Index - 1 > Toks.First_Index and then Is_Word (Toks (Index - 2), "not")));

      --  Whether the word at Spot names something else than a use of the
      --  subprogram: its own declaration or its end ("end Name;"), a
      --  parameter, component or object of that name (followed by ':'), a
      --  formal in a named association (followed by "=>"), a selected
      --  component (after '.'), or a pragma's argument.
      function Is_No_Use (Toks : Token_List; Spot : Positive) return Boolean is
        ((Spot > Toks.First_Index and then Declares (Toks, Spot - 1))
         or else (Spot > Toks.First_Index and then Is_Word (Toks (Spot - 1), "end"))
         or else (Spot < Toks.Last_Index
                  and then (Is_Symbol (Toks (Spot + 1), ":") or else Is_Symbol (Toks (Spot + 1), "=>")))
         or else (Spot > Toks.First_Index and then Is_Symbol (Toks (Spot - 1), "."))
         or else (Spot >= Toks.First_Index + 3
                  and then Is_Symbol (Toks (Spot - 1), "(")
                  and then Is_Word (Toks (Spot - 3), "pragma")));

      procedure Index_Names (Path : String) is
         File      : constant String := Ada.Directories.Simple_Name (Path);
         Own_Unit  : constant String := Unit_Of_File (Path);
         Toks      : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Seen      : File_Maps.Map;

         procedure Note (Name : String) is
         begin
            if Seen.Contains (Name) then
               return;
            end if;
            Seen.Insert (Name, "");
            if Named_In.Contains (Name) then
               Named_In.Replace (Name, Named_In.Element (Name) & File & ASCII.LF);
            else
               Named_In.Insert (Name, File & ASCII.LF);
            end if;
         end Note;

         --  Each unit's member Name reaches: "files.x.f.c" notes "files.x.f"
         --  when Files.X is a unit.
         procedure Note_With_Prefixes (Name : String) is
         begin
            for Index in Name'Range loop
               if Name (Index) = '.' and then Unit_Set.Contains (Name (Name'First .. Index - 1)) then
                  declare
                     Next_Dot : constant Natural :=
                       Ada.Strings.Fixed.Index (Name (Index + 1 .. Name'Last), ".");
                  begin
                     Note (Name (Name'First .. (if Next_Dot = 0 then Name'Last else Next_Dot - 1)));
                  end;
               end if;
            end loop;
         end Note_With_Prefixes;

         --  The use clauses this source sees but does not write, then the
         --  source itself.
         Seen_Uses : Token_List := Uses_Seen_By (Path);

         --  The words this source declares as an object, a parameter, a
         --  component or a loop or block name ("X, Y : T"), or as a
         --  subprogram of its own: a bare one written here names that, not
         --  an ancestor's subprogram.
         Locals : Name_Sets.Set;

         procedure Visit (Name : String; Next : Positive) is
            Last : constant Positive := Next - 1;
         begin
            --  A word written bare that is no use of a subprogram -- its own
            --  declaration, a parameter, component or object, a formal in a
            --  named association, a pragma's argument -- or that names this
            --  source's own declaration of that name.
            if not (Last > Seen_Uses.First_Index and then Is_Symbol (Seen_Uses (Last - 1), "."))
              and then (Is_No_Use (Seen_Uses, Last) or else Locals.Contains (To_String (Seen_Uses (Last).Text)))
            then
               return;
            end if;
            Note_With_Prefixes (Name);
            --  A child or subunit sees its ancestors' names directly.
            for Index in Own_Unit'Range loop
               if Own_Unit (Index) = '.' then
                  Note_With_Prefixes (Own_Unit (Own_Unit'First .. Index - 1) & "." & Name);
               end if;
            end loop;
            Note_With_Prefixes (Own_Unit & "." & Name);
         end Visit;
      begin
         Seen_Uses.Append (Toks);
         for Index in Toks.First_Index .. Toks.Last_Index loop
            if Declares (Toks, Index) then
               Locals.Include (To_String (Toks (Index + 1).Text));
            end if;
         end loop;
         for Index in Toks.First_Index + 1 .. Toks.Last_Index loop
            if Is_Symbol (Toks (Index), ":") and then Toks (Index - 1).Kind = Word then
               declare
                  Spot : Natural := Index - 1;
               begin
                  loop
                     Locals.Include (To_String (Toks (Spot).Text));
                     exit when Spot < Toks.First_Index + 2
                       or else not Is_Symbol (Toks (Spot - 1), ",")
                       or else Toks (Spot - 2).Kind /= Word;
                     Spot := Spot - 2;
                  end loop;
               end;
            end if;
         end loop;
         --  type T is new Unit.Parent ...: Unit's operations are inherited here.
         for Index in Toks.First_Index .. Toks.Last_Index - 1 loop
            if Is_Word (Toks (Index), "new") and then Toks (Index + 1).Kind = Word then
               declare
                  Named : Unbounded_String := Toks (Index + 1).Text;
                  Last  : Positive := Index + 1;
               begin
                  while Last + 2 <= Toks.Last_Index
                    and then Is_Symbol (Toks (Last + 1), ".")
                    and then Toks (Last + 2).Kind = Word
                  loop
                     Append (Named, "." & To_String (Toks (Last + 2).Text));
                     Last := Last + 2;
                  end loop;
                  declare
                     Full : constant String :=
                       Spelled_Out (To_String (Named), Aliases_Seen_By (All_Aliases, Own_Unit));
                     Dot  : constant Natural := Ada.Strings.Fixed.Index (Full, ".", Ada.Strings.Backward);
                  begin
                     if Dot > 0
                       and then Unit_Set.Contains (Full (Full'First .. Dot - 1))
                       and then Full (Full'First .. Dot - 1) /= Own_Unit
                     then
                        declare
                           Parent : constant String := Full (Full'First .. Dot - 1);
                        begin
                           if not Derived_In.Contains (Parent) then
                              Derived_In.Insert (Parent, Own_Unit & ASCII.LF);
                           elsif not Has_Line (Derived_In.Element (Parent), Own_Unit) then
                              Derived_In.Replace (Parent, Derived_In.Element (Parent) & Own_Unit & ASCII.LF);
                           end if;
                        end;
                     end if;
                  end;
               end;
            end if;
         end loop;
         For_Each_Resolved_Name (Seen_Uses, Aliases_Seen_By (All_Aliases, Own_Unit), Units, Visit'Access);
      end Index_Names;

      procedure Check_Spec (Path : String) is
         Text  : constant String := Project_Tools.Files.Read_Raw_File (Path);
         Stem  : constant String := Ada.Directories.Base_Name (Path);
         Unit  : constant String := Unit_Of_File (Path);
         --  The library unit's private part starts at a line "private" alone.
         Split : Natural := 0;
         Own   : Unbounded_String := To_Unbounded_String (Stem & ".ads" & ASCII.LF & Stem & ".adb" & ASCII.LF);
         All_Toks : constant Token_List := Tokens_Of (Text);
      begin
         declare
            Line_Start : Positive := Text'First;
         begin
            for Index in Text'Range loop
               if Text (Index) = ASCII.LF then
                  declare
                     Line : constant String :=
                       Ada.Strings.Fixed.Trim (Text (Line_Start .. Index - 1), Ada.Strings.Right);
                  begin
                     if Line = "private" or else Line = "private" & ASCII.CR then
                        Split := Line_Start;
                        exit;
                     end if;
                  end;
                  Line_Start := Index + 1;
               end if;
            end loop;
         end;
         for Item of Project_Tools.Files.List_Tree (Src, Stem & "-*.adb", Generated_Directories) loop
            if Is_Subunit_Of (To_String (Item), Unit) then
               Append (Own, Ada.Directories.Simple_Name (To_String (Item)) & ASCII.LF);
            end if;
         end loop;
         declare
            Public : constant Token_List :=
              Tokens_Of (Text (Text'First .. (if Split = 0 then Text'Last else Split - 1)));
            Header : Natural := 0;
         begin
            --  Past the unit's own header (a generic's formal part included).
            for Index in Public.First_Index .. Public.Last_Index loop
               if Is_Word (Public (Index), "package") then
                  Header := Index;
                  exit;
               end if;
            end loop;
            if Header = 0 then
               return;
            end if;
            for Index in Header + 1 .. Public.Last_Index loop
               if Declares (Public, Index) and then not Overrides (Public, Index) then
                  declare
                     Name      : constant String := To_String (Public (Index + 1).Text);
                     Full      : constant String := Unit & "." & Name;
                     Uses      : Natural := 0;
                     Elsewhere : Boolean := False;

                     procedure Other (File : String; Number : Positive) is
                        pragma Unreferenced (Number);
                     begin
                        if not Has_Line (To_String (Own), File) then
                           Elsewhere := True;
                        end if;
                     end Other;

                     procedure Inherited (Deriving : String; Number : Positive) is
                        pragma Unreferenced (Number);
                     begin
                        if Named_In.Contains (Deriving & "." & Name) then
                           For_Each_Line (Named_In.Element (Deriving & "." & Name), Other'Access);
                        end if;
                     end Inherited;
                  begin
                     if Named_In.Contains (Full) then
                        For_Each_Line (Named_In.Element (Full), Other'Access);
                     end if;
                     if Derived_In.Contains (Unit) then
                        For_Each_Line (Derived_In.Element (Unit), Inherited'Access);
                     end if;
                     --  The spec's own uses: a generic's actual, a default.
                     for Spot in All_Toks.First_Index .. All_Toks.Last_Index loop
                        if Is_Word (All_Toks (Spot), Name) and then not Is_No_Use (All_Toks, Spot) then
                           Uses := Uses + 1;
                        end if;
                     end loop;
                     if not Elsewhere and then Uses = 0 and then not Has_Line (Exempt, Full) then
                        Report (Path & ": " & Name & " is public, but only its own unit and the suite name it;"
                           & " declare it in the private part and reach it through a *.Testing child");
                     end if;
                  end;
               end if;
            end loop;
         end;
      end Check_Spec;
   begin
      For_Each_Line (Units, Add_Unit'Access);
      for Item of Sources loop
         Index_Names (To_String (Item));
      end loop;
      for Item of Sources loop
         if Ada.Strings.Fixed.Tail (To_String (Item), 4) = ".ads" then
            Check_Spec (To_String (Item));
         end if;
      end loop;
   end Check_Test_Only_Api;
