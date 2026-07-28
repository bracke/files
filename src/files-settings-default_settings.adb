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

      Args.Append (To_Unbounded_String ("{path}"));
      Add_Open_Action (Settings, "text/plain", Make_Action ("xdg-open", Args));
      return Settings;
   end Default_Settings;
