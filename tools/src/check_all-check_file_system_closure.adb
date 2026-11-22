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
         Stem : String := Ada.Characters.Handling.To_Lower (Unit);
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
            if Is_Subunit_Of (To_String (Path), Ada.Characters.Handling.To_Lower (Unit)) then
               Reach (Ada.Directories.Simple_Name (To_String (Path)), From);
            end if;
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
      begin
         for Unit of Tokens.With_Units_Of (Project_Tools.Files.Read_Raw_File (Src & "/" & File)) loop
            declare
               Name : constant String := To_String (Unit);
            begin
               if Name'Length > 6 and then Name (Name'First .. Name'First + 5) = "files." then
                  Reach_Unit (Name, File);
               end if;
            end;
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
