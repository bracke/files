separate (Files_Suite.Settings)
   procedure Test_Sort_Favorites_And_Mapping_Authority (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      declare
         Created_Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = created" & ASCII.LF);
         Modified_Parsed : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse ("[settings]" & ASCII.LF & "sort_field = modified" & ASCII.LF);
      begin
         Assert (Created_Parsed.Success, "settings parser accepts the created sort field");
         Files_Suite.Support.Assert_Equal
           (Created_Parsed.Settings.Sort_Field_Value,
            Files.Types.Sort_Created,
            "created sort field round-trips distinctly from modified");
         Files_Suite.Support.Assert_Equal
           (Modified_Parsed.Settings.Sort_Field_Value,
            Files.Types.Sort_Changed,
            "modified sort field still round-trips to modified");
      end;
      declare
         With_Favorites : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Round          : Files.Settings.Settings_Parse_Result;
         Found_Eq       : Boolean := False;
         Found_Hash     : Boolean := False;
         Found_File     : Boolean := False;
      begin
         With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("/data/a=b"));
         With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("#hashdir"));
         --  Favorites may reference files as well as folders; the path is
         --  stored verbatim and must survive the round-trip either way.
         With_Favorites.Favorite_Paths.Append (To_Unbounded_String ("/data/report.txt"));
         Round := Files.Settings.Parse (Files.Settings.To_Text (With_Favorites));
         Assert (Round.Success, "settings with tricky favorite paths round-trips");
         for P of Round.Settings.Favorite_Paths loop
            if To_String (P) = "/data/a=b" then
               Found_Eq := True;
            elsif To_String (P) = "#hashdir" then
               Found_Hash := True;
            elsif To_String (P) = "/data/report.txt" then
               Found_File := True;
            end if;
         end loop;
         Assert (Found_Eq, "a favorite path containing '=' survives the round-trip");
         Assert (Found_Hash, "a favorite path starting with '#' survives the round-trip");
         Assert (Found_File, "a favorite path pointing at a file survives the round-trip");
      end;
      declare
         Favorites : Files.Settings.Settings_Model :=
           Files.Settings.Default_Settings;
      begin
         Files.Settings.Toggle_Favorite_Path (Favorites, "/tmp/safe");
         Files.Settings.Toggle_Favorite_Path
           (Favorites, "/tmp/bad" & Character'Val (0) & "ignored");
         Files_Suite.Support.Assert_Equal
           (Natural (Favorites.Favorite_Paths.Length),
            1,
            "a NUL-containing path cannot be persisted as a favorite");
      end;
      declare
         --  The file is authoritative for mappings: a built-in mapping
         --  omitted from the file does not reappear from the defaults, while
         --  a fresh install still gets the defaults (seeded into the file by
         --  Ensure_Default_File).
         Authoritative : constant Files.Settings.Settings_Parse_Result :=
           Files.Settings.Parse
             ("[filetypes]" & ASCII.LF & "custom = application/x-custom" & ASCII.LF);
      begin
         Assert (Authoritative.Success, "settings with an explicit filetypes section parses");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "custom"),
            "application/x-custom",
            "an explicit filetype mapping loads from the file");
         Files_Suite.Support.Assert_Equal
           (Files.Settings.Filetype_For_Extension (Authoritative.Settings, "txt"),
            "",
            "a built-in mapping omitted from the file does not reappear");
         Assert
           (Files.Settings.Filetype_For_Extension (Files.Settings.Default_Settings, "txt") /= "",
            "built-in defaults still provide mappings for a fresh install");
      end;
   end Test_Sort_Favorites_And_Mapping_Authority;
