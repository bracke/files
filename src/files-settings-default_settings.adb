with Hostkit.Process;
with Files.Settings.Open_Actions;
separate (Files.Settings)
   function Default_Settings return Settings_Model is
      Settings : Settings_Model;
      Args     : String_Vectors.Vector;
   begin
      Settings.Icon_Theme := Files.Icon_Themes.Basic;
      declare
         Defaults : constant Files.File_Types.Classification := Files.File_Types.Default_Classification;
      begin
         Settings.Extension_Filetypes := Defaults.Extension_Filetypes;
         Settings.Icon_Mappings := Defaults.Icon_Mappings;
      end;

      --  The one seeded open action, and it has to name a program this host
      --  actually has: Lookup_Open_Action prefers a configured action over the
      --  system default, so an opener the host lacks would shadow the working
      --  fallbacks, and Ensure_Default_File writes these defaults out into the
      --  user's settings file.
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
         Add_Open_Action (Settings, "text/plain", Open_Actions.Make_Action (To_String (Program), Args));
      end;

      return Settings;
   end Default_Settings;
