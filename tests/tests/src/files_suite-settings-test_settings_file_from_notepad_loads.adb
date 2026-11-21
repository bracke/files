with Files.Preference_Types;
with Files.Settings.Path_References;
separate (Files_Suite.Settings)
   --  Windows Notepad saves a hand-edited settings file with a UTF-8
   --  byte-order mark and CRLF line ends. The whole file loads or nothing
   --  does, so a regression in either the BOM skip or the CR trim would
   --  reject every setting in it.
   procedure Test_Settings_File_From_Notepad_Loads (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      CRLF : constant String := ASCII.CR & ASCII.LF;
      BOM  : constant String := Character'Val (16#EF#) & Character'Val (16#BB#) & Character'Val (16#BF#);
      Text : constant String :=
        BOM & "[settings]" & CRLF
        & "show_hidden_files = true" & CRLF
        & "default_view_mode = details" & CRLF
        & "[bookmarks]" & CRLF
        & "bookmark = ""/home/user/My Docs""" & CRLF;
      Parsed : constant Files.Settings.Settings_Parse_Result := Files.Settings.Parse (Text);
   begin
      Assert (Parsed.Success, "a BOM and CRLF line ends do not reject the file");
      Assert (Parsed.Settings.Show_Hidden_Files, "a boolean before a CR loads");
      Assert (Parsed.Settings.Default_View = Files.Preference_Types.Details, "a keyword before a CR loads");
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Settings.Path_References.Favorite_Paths (Parsed.Settings).Length), 1,
         "the quoted bookmark loads");
      Files_Suite.Support.Assert_Equal
        (Ada.Strings.Unbounded.To_String (Files.Settings.Path_References.Favorite_Paths (Parsed.Settings) (1)),
         "/home/user/My Docs",
         "a quoted value keeps its inner space and loses its quotes and the CR");
   end Test_Settings_File_From_Notepad_Loads;
