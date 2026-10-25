separate (Files_Suite.Settings)
   procedure Test_Filetype_And_Icon_Mappings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Open_Action_Settings_Text);
      Manual : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   begin
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, ".ada"),
         "text/x-ada",
         "extension mapping parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, " ADA "),
         "text/x-ada",
         "extension lookup normalizes whitespace and case");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "log"),
         "text/x-log",
         "quoted filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "quote"),
         "text/""quoted",
         "quote-containing filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "eq"),
         "text/with=equals",
         "equals-containing filetype mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Normalize_Extension ("."),
         "",
         "single-dot extension normalizes to empty");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Normalize_Extension (". TXT "),
         "txt",
         "extension normalization trims after a leading dot");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "."),
         "",
         "empty normalized extension has no filetype mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Parsed.Settings, "unknown"),
         "",
         "unknown extension has no filetype mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "pdf"),
         "application/pdf",
         "default settings map PDF files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "adb"),
         "text/x-ada",
         "default settings map Ada body files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "json"),
         "application/json",
         "default settings map JSON files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "xml"),
         "application/xml",
         "default settings map XML files");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "zip"),
         "application/zip",
         "default settings map ZIP archives");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "tar.gz"),
         "application/gzip-tar",
         "default settings map compressed tar archives");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "docx"),
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "default settings map Word documents");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "xlsx"),
         "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         "default settings map spreadsheet documents");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "mp3"),
         "audio/mpeg",
         "default settings map MP3 audio");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Manual, "mp4"),
         "video/mp4",
         "default settings map MP4 video");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "inode/directory"),
         "folder",
         "default settings map directory icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "inode/symlink"),
         "link",
         "default settings map symlink icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-executable"),
         "executable",
         "default settings map executable icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/plain"),
         "text",
         "default settings map text icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "text/x-ada"),
         "ada",
         "default settings map Ada icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "image/png"),
         "image",
         "default settings map PNG icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "application/x-tar"),
         "unknown",
         "default settings map tar icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Manual, "audio/mpeg"),
         "unknown",
         "default settings map audio icons");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-ada"),
         "text",
         "icon mapping parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, " text/x-ada "),
         "text",
         "icon lookup normalizes whitespace");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-log"),
         "log-icon",
         "quoted icon mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-quote"),
         "quote""icon",
         "quoted icon mapping unescapes doubled quotes");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "text/x-equals"),
         "icon=equals",
         "equals-containing icon mapping value parses");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "application/x-missing"),
         "",
         "unknown filetype has no icon mapping");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Icon_For_Filetype (Parsed.Settings, "   "),
         "",
         "blank filetype has no icon mapping");
   end Test_Filetype_And_Icon_Mappings;
