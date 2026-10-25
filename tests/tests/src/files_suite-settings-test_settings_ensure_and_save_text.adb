separate (Files_Suite.Settings)
   procedure Test_Settings_Ensure_And_Save_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Loaded        : Files.Settings.Settings_Parse_Result;
      Ensured_Path  : constant String := Join (Join (Root, "created-config"), "settings.conf");
      Ensured       : Files.Settings.Settings_Write_Result;
      Saved_Path    : constant String := Join (Join (Root, "saved-config"), "settings.conf");
      Blocked_Parent : constant String := Join (Root, "blocked-parent");
      Blocked_Path   : constant String := Join (Blocked_Parent, "settings.conf");
      Saved         : Files.Settings.Settings_Write_Result;
   begin
      Reset_Root;
      Ensured := Files.Settings.Ensure_Default_File (Ensured_Path);
      Assert (Ensured.Success, "ensure default settings creates missing file");
      Assert (Ada.Directories.Exists (Ensured_Path), "ensure default settings creates parent directories");
      Loaded := Files.Settings.Load_File (Ensured_Path);
      Assert (Loaded.Success, "ensured default settings file loads");
      Files_Suite.Support.Assert_Equal
        (Files.Settings.Filetype_For_Extension (Loaded.Settings, "txt"),
         "text/plain",
         "ensured settings file contains default mappings");
      Saved := Files.Settings.Save_Text (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
      Assert (Saved.Success, "settings text can be saved to a new path");
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         declare
            Linked : constant String := Saved_Path & ".link";
            Result : Files.Settings.Settings_Write_Result;
         begin
            Assert (Hostkit.Fs.Create_Link (Saved_Path, Linked), "prepare a symlinked settings file");
            Result := Files.Settings.Save_Text
              (Linked, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
            Assert (Result.Success and then Hostkit.Fs.Is_Link (Linked),
                    "saving through a symlinked settings file keeps the link");
            Files_Suite.Support.Assert_Equal
              (Files.Settings.Load_File (Saved_Path).Settings.Default_View,
               Files.Types.Details,
               "the save lands in the link's target");
            Saved := Files.Settings.Save_Text
              (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
            Assert (Hostkit.Fs.Delete_Link (Linked), "remove the test link");
         end;
      end if;
      if Hostkit.Metadata.Mode_Bits_Are_Native then
         declare
            Available : Boolean := False;
         begin
            Assert
              (Files.File_System.Permission_Bits_Of (Saved_Path, Available)
                 mod 8#1000# = 8#600# and then Available,
               "saved settings containing private paths are owner-only");
         end;
      end if;
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert (Loaded.Success, "saved settings file loads");
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Large_Icons,
         "saved settings text is persisted");
      --  Saving over an existing file goes through the atomic temp+rename path:
      --  the new content replaces the old and no temporary file is left behind.
      Saved :=
        Files.Settings.Save_Text
          (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = details" & ASCII.LF);
      Assert (Saved.Success, "settings text can be saved over an existing file");
      Assert
        (not Ada.Directories.Exists (Saved_Path & ".tmp"),
         "a successful settings save leaves no temporary file behind");
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert (Loaded.Success, "resaved settings file loads");
      Files_Suite.Support.Assert_Equal
        (Loaded.Settings.Default_View,
         Files.Types.Details,
         "resaved settings text replaces the previous content");
      Saved := Files.Settings.Save_Text
        (Saved_Path,
         "[settings]" & ASCII.LF
         & "default_view_mode = large" & Character'Val (0) & "ignored"
         & ASCII.LF);
      Assert
        (not Saved.Success,
         "settings saving rejects embedded NUL bytes");
      Loaded := Files.Settings.Load_File (Saved_Path);
      Assert
        (Loaded.Success
         and then Loaded.Settings.Default_View = Files.Types.Details,
         "a rejected NUL-containing save preserves the existing settings file");
      declare
         --  On the heap: a megabyte on the stack overflowed Windows' 1 MiB
         --  main stack once the code below this test grew.
         type Text_Access is access String;
         procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);
         Oversized_Text : Text_Access := new String'[1 .. 1 * 1024 * 1024 + 1 => 'x'];
      begin
         Saved := Files.Settings.Save_Text (Saved_Path, Oversized_Text.all);
         Free (Oversized_Text);
         Assert
           (not Saved.Success,
            "settings saving rejects text that its bounded loader cannot read");
         Loaded := Files.Settings.Load_File (Saved_Path);
         Assert
           (Loaded.Success
            and then Loaded.Settings.Default_View = Files.Types.Details,
            "a rejected oversized save preserves the existing settings file");
      end;
      declare
         Temp_Path : constant String := Saved_Path & ".tmp";
         Victim : constant String := Join (Root, "settings-temp-victim");
      begin
         Write_File (Victim, "must stay intact");
         if Files_Suite.Support.Create_Symlink (Victim, Temp_Path) then
            Saved := Files.Settings.Save_Text
              (Saved_Path, "[settings]" & ASCII.LF & "default_view_mode = large" & ASCII.LF);
            Assert (Saved.Success, "settings save skips an occupied temp pathname");
            Assert (Hostkit.Fs.Is_Link (Temp_Path),
                    "settings save preserves a colliding temp symlink");
            Assert (File_Has_Bytes (Victim, "must stay intact"),
                    "settings save never follows and truncates a temp symlink target");
            Assert (not Ada.Directories.Exists (Saved_Path & ".tmp-2")
                      and then not Hostkit.Fs.Is_Link (Saved_Path & ".tmp-2"),
                    "settings save removes its alternate temporary file");
         end if;
      end;
      Write_File (Blocked_Parent, "not a directory");
      Saved := Files.Settings.Save_Text (Blocked_Path, "[settings]" & ASCII.LF);
      Assert (not Saved.Success, "settings save rejects a file used as parent directory");
      Files_Suite.Support.Assert_Equal
        (To_String (Saved.Path),
         Blocked_Path,
         "settings save parent failure reports requested settings path");
      Files_Suite.Support.Assert_Equal
        (To_String (Saved.Error_Key),
         "error.settings.not_file",
         "settings save parent failure reports not-file diagnostic");
   end Test_Settings_Ensure_And_Save_Text;
