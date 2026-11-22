with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Vectors;

separate (Check_All)
   procedure Check_File_System_Closure is
      --  Files.File_System takes the classification it maps items by
      --  (Files.File_Types.Classification), never the settings: no unit its
      --  specs, bodies or subunits reach, however indirectly, is
      --  Files.Settings or a child of it. Every with clause is followed --
      --  into each named unit's spec, body, subunits and parents' specs --
      --  so a settings dependency that arrives through a helper unit is
      --  found too, and named with the chain of files that reached it.
      package Parent_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type        => String,
         Element_Type    => String,
         Hash            => Ada.Strings.Hash,
         Equivalent_Keys => "=");

      package File_Vectors is new Ada.Containers.Indefinite_Vectors
        (Index_Type   => Positive,
         Element_Type => String);

      Src     : constant String := Root & "/src";
      Reached : Parent_Maps.Map;
      Queue   : File_Vectors.Vector;
      Next    : Positive := 1;
      --  The files a settings unit was reached from, each reported once.
      Entries : Parent_Maps.Map;

      function Lower (Text : String) return String renames Ada.Characters.Handling.To_Lower;

      --  Text without the blanks, tabs and line ends around it.
      function Trimmed (Text : String) return String is
         First : Positive := Text'First;
         Last  : Natural := Text'Last;
      begin
         while First <= Last and then Text (First) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR | ASCII.FF loop
            First := First + 1;
         end loop;
         while Last >= First and then Text (Last) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR | ASCII.FF loop
            Last := Last - 1;
         end loop;
         return Text (First .. Last);
      end Trimmed;

      --  Note File (a simple name in src) reached from From, once.
      procedure Reach (File, From : String) is
      begin
         if not Reached.Contains (File) then
            Reached.Insert (File, From);
            Queue.Append (File);
         end if;
      end Reach;

      --  The files a with of Unit brings in: its spec and parents' specs,
      --  its body and that body's subunits.
      procedure Reach_Unit (Unit, From : String) is
         Stem : String := Lower (Unit);
         Dash : Natural;
      begin
         for C of Stem loop
            if C = '.' then
               C := '-';
            end if;
         end loop;
         for Suffix of String_List'[To_Unbounded_String (".ads"), To_Unbounded_String (".adb")] loop
            if Ada.Directories.Exists (Src & "/" & Stem & To_String (Suffix)) then
               Reach (Stem & To_String (Suffix), From);
            end if;
         end loop;
         for Path of Project_Tools.Files.List_Tree (Src, Stem & "-*.adb", Generated_Directories) loop
            declare
               Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (To_String (Path))));
            begin
               if Ada.Strings.Fixed.Index (Code, "separate") > 0 then
                  Reach (Ada.Directories.Simple_Name (To_String (Path)), From);
               end if;
            end;
         end loop;
         Dash := Ada.Strings.Fixed.Index (Stem, "-", Ada.Strings.Backward);
         while Dash > 0 loop
            if Ada.Directories.Exists (Src & "/" & Stem (Stem'First .. Dash - 1) & ".ads") then
               Reach (Stem (Stem'First .. Dash - 1) & ".ads", From);
            end if;
            Dash := Ada.Strings.Fixed.Index (Stem (Stem'First .. Dash - 1), "-", Ada.Strings.Backward);
         end loop;
      end Reach_Unit;

      --  Every Files unit File's with clauses name.
      procedure Follow (File : String) is
         Code  : constant String :=
           Code_Of (To_String (Project_Tools.Text.Read_Text_File (Src & "/" & File)), Blank_Strings => True);
         Start : Positive := Code'First;
         Stop  : Natural;
      begin
         while Start <= Code'Last loop
            Stop := Ada.Strings.Fixed.Index (Code (Start .. Code'Last), ";");
            exit when Stop = 0;
            declare
               Clause : constant String := Lower (Trimmed (Code (Start .. Stop - 1)));
               Kept   : constant String := Trimmed
                 (if Clause'Length > 8 and then Clause (Clause'First .. Clause'First + 7) = "limited "
                  then Clause (Clause'First + 8 .. Clause'Last) else Clause);
               Names  : constant String := Trimmed
                 (if Kept'Length > 8 and then Kept (Kept'First .. Kept'First + 7) = "private "
                  then Kept (Kept'First + 8 .. Kept'Last) else Kept);
               From   : Positive;
            begin
               --  Context clauses come first; the first other declaration ends them.
               exit when not (Names'Length > 5 and then Names (Names'First .. Names'First + 4) = "with ")
                 and then not (Names'Length > 4 and then Names (Names'First .. Names'First + 3) = "use ")
                 and then not (Names'Length > 6 and then Names (Names'First .. Names'First + 5) = "pragma");
               if Names'Length > 5 and then Names (Names'First .. Names'First + 4) = "with " then
                  From := Names'First + 5;
                  for I in Names'First + 5 .. Names'Last + 1 loop
                     if I > Names'Last or else Names (I) = ',' then
                        declare
                           Unit : constant String := Trimmed (Names (From .. I - 1));
                        begin
                           if Unit'Length > 6 and then Unit (Unit'First .. Unit'First + 5) = "files." then
                              Reach_Unit (Unit, File);
                           end if;
                        end;
                        From := I + 1;
                     end if;
                  end loop;
               end if;
            end;
            Start := Stop + 1;
         end loop;
      end Follow;

      --  The chain of files that reached File, from the File_System unit.
      function Chain (File : String) return String is
         From : constant String := Reached.Element (File);
      begin
         return (if From = "" then File else File & " <- " & Chain (From));
      end Chain;
   begin
      for Pattern of String_List'[To_Unbounded_String ("files-file_system.ad?"),
                                  To_Unbounded_String ("files-file_system-*.ad?")]
      loop
         for Path of Project_Tools.Files.List_Tree (Src, To_String (Pattern), Generated_Directories) loop
            Reach (Ada.Directories.Simple_Name (To_String (Path)), "");
         end loop;
      end loop;
      while Next <= Natural (Queue.Length) loop
         declare
            File : constant String := Queue (Next);
         begin
            Next := Next + 1;
            if File = "files-settings.ads" or else File = "files-settings.adb"
              or else (File'Length > 15 and then File (File'First .. File'First + 14) = "files-settings-")
            then
               --  One report per file that brings the settings in, naming
               --  the chain to it; the settings' own files are not followed.
               if not Entries.Contains (Reached.Element (File)) then
                  Entries.Insert (Reached.Element (File), File);
                  Report ("Files.File_System reaches Files.Settings: " & Chain (File));
               end if;
            else
               Follow (File);
            end if;
         end;
      end loop;
      if Reached.Is_Empty then
         Report ("Check_File_System_Closure found no Files.File_System source under " & Src);
      end if;
   end Check_File_System_Closure;
