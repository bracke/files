with Files.Settings.Storage;
with Files.File_Identities.Testing;
separate (Files_Suite.Settings)
   --  A save writes a temporary beside the settings and publishes it. When the
   --  temporary's identity could not be read, the cleanup -- which removes
   --  only the file whose identity it holds -- removed nothing, so each failed
   --  save left one more settings.tmp, settings.tmp-2, ... behind. A file this
   --  save just created exclusively is its own to remove.
   procedure Test_A_Failed_Save_Leaves_No_Temporary (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Folder : constant String := Join (Root, "no-identity-config");
      Path   : constant String := Join (Folder, "settings.conf");
      Saved  : Files.Settings.Settings_Write_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Folder);
      Files.File_Identities.Testing.Set_Unavailable (True);
      Saved := Files.Settings.Storage.Save_Text (Path, "[settings]" & ASCII.LF);
      Files.File_Identities.Testing.Set_Unavailable (False);
      Assert (not Saved.Success, "a save whose temporary has no identity fails");
      Assert (not Ada.Directories.Exists (Path & ".tmp"), "and leaves no temporary behind");
      Saved := Files.Settings.Storage.Save_Text (Path, "[settings]" & ASCII.LF);
      Assert (Saved.Success and then not Ada.Directories.Exists (Path & ".tmp-2"),
              "so the next save takes the first temporary name again and succeeds");
   exception
      when others =>
         Files.File_Identities.Testing.Set_Unavailable (False);
         raise;
   end Test_A_Failed_Save_Leaves_No_Temporary;
