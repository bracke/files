with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   --  An item on another volume than the home trash goes to that volume's own
   --  freedesktop trash ($topdir/.Trash-$uid): a rename there, not a copy of
   --  everything into home. The trash view lists it with the home trash's
   --  items, and restore, delete and the recorded original path work on it.
   procedure Test_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote    : Files_Suite.Volumes.Remote_Directory;
      Data_Home : constant String := Root & "_volume_trash_data";
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
      Volume_Base : Unbounded_String;

      --  Remote removes the volume trash it saw appear.
      procedure Clean is
      begin
         Project_Tools.Files.Delete_Tree (Data_Home);
      end Clean;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Skip ("Test_Volume_Trash", "Windows has no freedesktop volume trash");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-volume-trash-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Volume_Trash", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Data_Home);
      Project_Tools.Files.Delete_Tree (Data_Home);

      declare
         Home_Item   : constant String := Join (Root, "home-item.txt");
         Volume_Item : constant String := Join (Remote.Path, "volume-item.txt");
         Home_Trashed, Trashed : Files.Types.UString;
         Result      : Files.File_System.Mutation_Result;
      begin
         --  The home trash first, so its files/ folder exists for the view.
         Write_File (Home_Item, "home");
         Result := Files.File_System.Move_To_Trash (Home_Item, Home_Trashed);
         Assert (Result.Success, "an item beside the home trash goes to the home trash");

         Write_File (Volume_Item, "volume");
         --  No administrator's .Trash on a test volume: the per-user one.
         Volume_Base := To_Unbounded_String (Files_Suite.Volumes.Volume_Trash_Of (Remote.Path));
         declare
            Before : constant String := Files.File_Identities.Token (Volume_Item);
         begin
            Result := Files.File_System.Move_To_Trash (Volume_Item, Trashed);
            Assert (Result.Success, "an item on another volume is trashed");
            Files_Suite.Support.Assert_Equal
              (Files.File_Identities.Token (To_String (Trashed)), Before,
               "it was renamed into its volume's trash, not copied");
            Assert (Files.File_System.Is_Volume_Trash_Item (To_String (Trashed)),
                    "trash-view actions know it for a trash item (Delete removes its info file too)");
         end;
         Files_Suite.Support.Assert_Equal
           (Ada.Directories.Containing_Directory (To_String (Trashed)),
            Join (To_String (Volume_Base), "files"),
            "the item went to its volume's trash, not to the home trash");
         Assert
           (Ada.Directories.Exists
              (Join (Join (To_String (Volume_Base), "info"),
                     Ada.Directories.Simple_Name (To_String (Trashed)) & ".trashinfo")),
            "the volume trash records where the item came from");
         Files_Suite.Support.Assert_Equal
           (Files.File_System.Trash_Original_Path (To_String (Trashed)),
            Volume_Item,
            "the recorded original path is the item's");
         Assert
           (Ada.Strings.Fixed.Index
              (Project_Tools.Files.Read_Raw_File
                 (Join (Join (To_String (Volume_Base), "info"),
                        Ada.Directories.Simple_Name (To_String (Trashed)) & ".trashinfo")),
               "Path=/") = 0,
            "a volume trash records the path relative to the volume's top, so a remount keeps it");

         --  What another file manager left: a relative Path= resolves against
         --  the volume; an absolute one off the volume is not trusted.
         declare
            Info : constant String := Join (To_String (Volume_Base), "info");
            Foreign : constant String := Join (Join (To_String (Volume_Base), "files"), "foreign.txt");
            Top : constant String := Ada.Directories.Containing_Directory (To_String (Volume_Base));
         begin
            Write_File (Foreign, "foreign");
            Write_File
              (Join (Info, "foreign.txt.trashinfo"),
               "[Trash Info]" & ASCII.LF & "Path=some%20folder/foreign.txt" & ASCII.LF
               & "DeletionDate=2026-01-01T00:00:00" & ASCII.LF);
            Files_Suite.Support.Assert_Equal
              (Files.File_System.Trash_Original_Path (Foreign),
               Join (Join (Top, "some folder"), "foreign.txt"),
               "a relative recorded path resolves against the volume's top");
            Write_File
              (Join (Info, "foreign.txt.trashinfo"),
               "[Trash Info]" & ASCII.LF & "Path=/home/someone/.config/autostart/x.desktop" & ASCII.LF);
            Files_Suite.Support.Assert_Equal
              (Files.File_System.Trash_Original_Path (Foreign), "",
               "a recorded path off the volume is not where a restore may land");
            Write_File
              (Join (Info, "foreign.txt.trashinfo"),
               "[Trash Info]" & ASCII.LF & "Path=../../escape.txt" & ASCII.LF);
            Files_Suite.Support.Assert_Equal
              (Files.File_System.Trash_Original_Path (Foreign), "",
               "a recorded path may not climb out of the volume");
            Assert (Files.File_System.Delete_Trashed_Item (Foreign).Success, "remove the foreign item");
         end;

         declare
            Load  : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings);
            Found_Home, Found_Volume : Boolean := False;
         begin
            Assert (Load.Success, "the trash view lists");
            for Item of Load.Items loop
               Found_Home := Found_Home or else Item.Full_Path = Home_Trashed;
               Found_Volume := Found_Volume or else Item.Full_Path = Trashed;
            end loop;
            Assert (Found_Home, "the trash view lists the home trash's items");
            Assert (Found_Volume, "the trash view lists the volume trash's items too");
         end;

         Result := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Assert (Result.Success, "an item restores from its volume's trash");
         Assert (File_Has_Bytes (Volume_Item, "volume"), "it is back where it was");

         Result := Files.File_System.Move_To_Trash (Volume_Item, Trashed);
         Assert (Result.Success, "trashed again");
         Result := Files.File_System.Delete_Trashed_Item (To_String (Trashed));
         Assert (Result.Success, "an item is deleted from its volume's trash");
         Assert (not Ada.Directories.Exists (To_String (Trashed)), "the payload is gone");

         Result := Files.File_System.Delete_Trashed_Item (To_String (Home_Trashed));
         Assert (Result.Success, "the home trash's item is deleted too");
      end;

      --  A volume trash whose files/ is a link is no trash: Empty Trash
      --  would delete what it points at.
      declare
         Target : constant String := Join (Root, "not-trash");
         Files_Dir : constant String := Join (To_String (Volume_Base), "files");
         Kept : constant String := Join (Target, "kept.txt");
      begin
         Ada.Directories.Create_Path (Target);
         Write_File (Kept, "kept");
         Project_Tools.Files.Delete_Tree (Files_Dir);
         if Files_Suite.Support.Create_Symlink (Target, Files_Dir) then
            Assert (not Files.File_System.Is_Volume_Trash_Item (Join (Files_Dir, "kept.txt")),
                    "an item reached through a linked files/ is not a trash item");
            Assert (not Files.File_System.Delete_Trashed_Item (Join (Files_Dir, "kept.txt")).Success,
                    "and is not deleted as one");
            Assert (File_Has_Bytes (Kept, "kept"), "what the link points at is untouched");
            Ada.Directories.Delete_File (Files_Dir);
         else
            --  The second volume, not the test root: a FAT stick has no links.
            Files_Suite.Support.Skip ("Test_Volume_Trash", "the second volume takes no symbolic links");
         end if;
         Ada.Directories.Create_Directory (Files_Dir);
      end;
      Clean;
   exception
      when others =>
         Clean;
         raise;
   end Test_Volume_Trash;
