separate (Files_Suite.Operations)
   procedure Test_Settings_Save_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Locked : constant String := Join (Root, "locked");
      Path : constant String := Join (Locked, "settings.conf");
      Saved : Files.Settings.Settings_Write_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Locked);
      if not Lock_Directory (Locked) then
         Unlock_Directory (Locked);
         Files_Suite.Support.Skip
           ("Test_Settings_Save_Read_Only_Cause", "a read-only directory does not refuse writes here");
         return;
      end if;
      Saved := Files.Settings.Save_Text (Path, Files.Settings.Default_Settings_Text);
      Assert (not Saved.Success, "a read-only folder refuses the settings file");
      Assert_Equal (To_String (Saved.Error_Key), "error.io.denied", "the refused save says permission was denied");
      Saved := Files.Settings.Ensure_Default_File (Path);
      Assert_Equal
        (To_String (Saved.Error_Key), "error.io.denied", "the refused default settings say permission was denied");
      Unlock_Directory (Locked);
      Assert (not Ada.Directories.Exists (Path) and then not Ada.Directories.Exists (Path & ".tmp"),
              "a refused save leaves no settings or temporary file");
   exception
      when others =>
         Unlock_Directory (Locked);
         raise;
   end Test_Settings_Save_Read_Only_Cause;
