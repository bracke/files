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
      --  Each word, lower case, and the simple names of the sources naming it, one a line.
      Named_In : File_Maps.Map;

      procedure Index_Words (Path : String) is
         Name : constant String := Ada.Directories.Simple_Name (Path);
         Toks : constant Token_List := Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Seen : File_Maps.Map;
      begin
         for Item of Toks loop
            if Item.Kind = Word and then not Seen.Contains (To_String (Item.Text)) then
               declare
                  Text : constant String := To_String (Item.Text);
               begin
                  Seen.Insert (Text, "");
                  if Named_In.Contains (Text) then
                     Named_In.Replace (Text, Named_In.Element (Text) & Name & ASCII.LF);
                  else
                     Named_In.Insert (Text, Name & ASCII.LF);
                  end if;
               end;
            end if;
         end loop;
      end Index_Words;

      --  Whether Toks (Index) starts a subprogram declaration (not a formal
      --  subprogram, nor an access-to-subprogram type).
      function Declares (Toks : Token_List; Index : Positive) return Boolean is
        ((Is_Word (Toks (Index), "procedure") or else Is_Word (Toks (Index), "function"))
         and then Index < Toks.Last_Index
         and then Toks (Index + 1).Kind = Word
         and then (Index = Toks.First_Index
                   or else not (Is_Word (Toks (Index - 1), "access") or else Is_Word (Toks (Index - 1), "with"))));

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
               if Declares (Public, Index) then
                  declare
                     Name         : constant String := To_String (Public (Index + 1).Text);
                     Uses         : Natural := 0;
                     Elsewhere    : Boolean := False;

                     procedure Other (File : String; Number : Positive) is
                        pragma Unreferenced (Number);
                     begin
                        if not Has_Line (To_String (Own), File) then
                           Elsewhere := True;
                        end if;
                     end Other;
                  begin
                     if Named_In.Contains (Name) then
                        For_Each_Line (Named_In.Element (Name), Other'Access);
                     end if;
                     --  The spec's own uses: a generic's actual, a default.
                     for Spot in All_Toks.First_Index .. All_Toks.Last_Index loop
                        if Is_Word (All_Toks (Spot), Name)
                          and then not (Spot > All_Toks.First_Index and then Declares (All_Toks, Spot - 1))
                        then
                           Uses := Uses + 1;
                        end if;
                     end loop;
                     if not Elsewhere and then Uses = 0 and then not Has_Line (Exempt, Unit & "." & Name) then
                        Report (Path & ": " & Name & " is public, but only its own unit and the suite name it;"
                           & " declare it in the private part and reach it through a *.Testing child");
                     end if;
                  end;
               end if;
            end loop;
         end;
      end Check_Spec;
   begin
      for Item of Sources loop
         Index_Words (To_String (Item));
      end loop;
      for Item of Sources loop
         if Ada.Strings.Fixed.Tail (To_String (Item), 4) = ".ads" then
            Check_Spec (To_String (Item));
         end if;
      end loop;
   end Check_Test_Only_Api;
