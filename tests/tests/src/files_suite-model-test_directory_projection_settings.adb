separate (Files_Suite.Model)
   procedure Test_Directory_Projection_Settings (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "projection");
      Tie_Dir  : constant String := Join (Root, "projection-ties");
      Modified_Dir : constant String := Join (Root, "projection-modified");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Dir, "zdir"));
      Write_File (Join (Dir, "c.bin"), "cccc");
      Write_File (Join (Dir, ".secret"));
      Write_File (Join (Dir, ".profile"));
      Write_File (Join (Dir, "afile.txt"), "a");
      Files.Settings.Add_Extension_Mapping (Settings, "profile", "text/x-profile");
      Files.Settings.Add_Extension_Mapping (Settings, "bin", "application/x-bin");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Load.Success, "directory projection loads");
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 3, "hidden files are hidden by default");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "afile.txt",
         "name ordering can sort files before dirs");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "c.bin",
         "name sort keeps files in deterministic order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "zdir",
         "directory follows file when name sort wins");

      Settings.Sort_Field_Value := Files.Types.Sort_Type;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "c.bin",
         "filetype sort uses configured field");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "zdir",
         "filetype ties fall back to name order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "afile.txt",
         "text file sorts after inode/filetype entries");

      Settings.Sort_Field_Value := Files.Types.Sort_Size;
      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "c.bin",
         "descending size sort uses metadata");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "afile.txt",
         "smaller file follows larger file");

      Settings.Show_Hidden_Files := True;
      Settings.Sort_Field_Value := Files.Types.Sort_Name;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 5, "show-hidden setting exposes dot files");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         ".profile",
         "hidden file participates in stable sorting");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         ".secret",
         "leading-dot files sort deterministically");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Filetype),
         "application/octet-stream",
         "leading-dot file loaded from disk does not use extension mapping");

      Ada.Directories.Create_Path (Join (Dir, ".vault"));
      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 3, "hidden directories are hidden by default");

      Settings.Show_Hidden_Files := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files_Suite.Support.Assert_Equal (Natural (Load.Items.Length), 6, "show-hidden setting exposes dot directories");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         ".profile",
         "hidden files sort by name with other items");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         ".secret",
         "hidden files remain in deterministic order");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         ".vault",
         "hidden directories sort by name with files");

      Ada.Directories.Create_Path (Tie_Dir);
      Write_File (Join (Tie_Dir, "B_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "a_equal.txt"), "same");
      Write_File (Join (Tie_Dir, "later.txt"), "larger");

      Settings.Show_Hidden_Files := False;
      Settings.Sort_Field_Value := Files.Types.Sort_Size;
      Settings.Sort_Ascending := True;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "a_equal.txt",
         "ascending size ties use name fallback");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "B_equal.txt",
         "ascending size tie fallback is deterministic");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "later.txt",
         "ascending size places larger item after ties");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Tie_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "later.txt",
         "descending size places larger item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (2).Name),
         "a_equal.txt",
         "descending size ties keep deterministic name fallback");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (3).Name),
         "B_equal.txt",
         "descending size tie fallback remains stable");

      Settings.Sort_Field_Value := Files.Types.Sort_Changed;
      Settings.Sort_Ascending := True;
      Ada.Directories.Create_Path (Modified_Dir);
      Write_File (Join (Modified_Dir, "old.txt"), "older");
      Write_File (Join (Modified_Dir, "new.txt"), "newer");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Join (Modified_Dir, "old.txt"),
         GNAT.OS_Lib.GM_Time_Of
           (Year   => 2020,
            Month  => 1,
            Day    => 1,
            Hour   => 0,
            Minute => 0,
            Second => 0));
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Join (Modified_Dir, "new.txt"),
         GNAT.OS_Lib.GM_Time_Of
           (Year   => 2022,
            Month  => 1,
            Day    => 1,
            Hour   => 0,
            Minute => 0,
            Second => 0));
      Load := Files.File_System.Load_Directory (Modified_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "old.txt",
         "modified sort orders older item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name),
         "new.txt",
         "modified sort orders newer item last");

      Settings.Sort_Ascending := False;
      Load := Files.File_System.Load_Directory (Modified_Dir, Settings);
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (1).Name),
         "new.txt",
         "descending modified sort orders newer item first");
      Files_Suite.Support.Assert_Equal
        (To_String (Load.Items.Element (Natural (Load.Items.Length)).Name),
         "old.txt",
         "descending modified sort orders older item last");
   end Test_Directory_Projection_Settings;
