with Hostkit.Process;
separate (Files.Settings)
   function Default_Settings return Settings_Model is
      Settings : Settings_Model;
      Args     : String_Vectors.Vector;
   begin
      Settings.Icon_Theme_Name := To_Unbounded_String ("files-basic");
      Add_Extension_Mapping (Settings, "txt", "text/plain");
      Add_Extension_Mapping (Settings, "adb", "text/x-ada");
      Add_Extension_Mapping (Settings, "ads", "text/x-ada");
      Add_Extension_Mapping (Settings, "md", "text/markdown");
      Add_Extension_Mapping (Settings, "json", "application/json");
      Add_Extension_Mapping (Settings, "xml", "application/xml");
      Add_Extension_Mapping (Settings, "png", "image/png");
      Add_Extension_Mapping (Settings, "jpg", "image/jpeg");
      Add_Extension_Mapping (Settings, "jpeg", "image/jpeg");
      Add_Extension_Mapping (Settings, "pdf", "application/pdf");
      Add_Extension_Mapping (Settings, "zip", "application/zip");
      Add_Extension_Mapping
        (Settings,
         "docx",
         "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
      Add_Extension_Mapping (Settings, "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
      Add_Extension_Mapping (Settings, "tar", "application/x-tar");
      Add_Extension_Mapping (Settings, "tar.gz", "application/gzip-tar");
      Add_Extension_Mapping (Settings, "gz", "application/gzip");
      Add_Extension_Mapping (Settings, "mp3", "audio/mpeg");
      Add_Extension_Mapping (Settings, "wav", "audio/wav");
      Add_Extension_Mapping (Settings, "mp4", "video/mp4");

      Add_Icon_Mapping (Settings, "inode/directory", "folder");
      Add_Icon_Mapping (Settings, "inode/symlink", "link");
      Add_Icon_Mapping (Settings, "application/x-executable", "executable");
      Add_Icon_Mapping (Settings, "text/plain", "text");
      Add_Icon_Mapping (Settings, "text/x-ada", "ada");
      Add_Icon_Mapping (Settings, "text/markdown", "text");
      Add_Icon_Mapping (Settings, "application/json", "text");
      Add_Icon_Mapping (Settings, "application/xml", "text");
      Add_Icon_Mapping (Settings, "image/png", "image");
      Add_Icon_Mapping (Settings, "image/jpeg", "image");
      Add_Icon_Mapping (Settings, "application/pdf", "text");
      Add_Icon_Mapping (Settings, "application/zip", "unknown");
      Add_Icon_Mapping (Settings, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "text");
      Add_Icon_Mapping (Settings, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "text");
      Add_Icon_Mapping (Settings, "application/x-tar", "unknown");
      Add_Icon_Mapping (Settings, "application/gzip-tar", "unknown");
      Add_Icon_Mapping (Settings, "application/gzip", "unknown");
      Add_Icon_Mapping (Settings, "audio/mpeg", "unknown");
      Add_Icon_Mapping (Settings, "audio/wav", "unknown");
      Add_Icon_Mapping (Settings, "video/mp4", "unknown");
      Add_Icon_Mapping (Settings, "application/octet-stream", "unknown");

      --  The one seeded open action, and it has to name a program this host
      --  actually has. It used to be xdg-open everywhere, which no Windows or
      --  macOS box has -- and because Lookup_Open_Action prefers a configured
      --  action over the system default, that entry did not merely fail to
      --  help: it shadowed the working `start` and `open` fallbacks, so a text
      --  file would not open at all. Worse, Ensure_Default_File writes these
      --  defaults out, so the dead entry was persisted into the user's
      --  settings file for them to find and delete by hand.
      --  The host's opener as a settings file keeps it: named, not located,
      --  so the file carries no one machine's absolute paths.
      declare
         Program : Unbounded_String;
         Given   : Hostkit.String_Vectors.Vector;
      begin
         Hostkit.Process.Portable_Default_Opener ("{path}", Program, Given);
         for Argument of Given loop
            Args.Append (Argument);
         end loop;
         Add_Open_Action (Settings, "text/plain", Make_Action (To_String (Program), Args));
      end;

      return Settings;
   end Default_Settings;
