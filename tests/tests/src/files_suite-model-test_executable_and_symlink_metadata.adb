separate (Files_Suite.Model)
   procedure Test_Executable_And_Symlink_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Run_Path  : constant String := Join (Root, "run.sh");
      --  What "executable" means is host-specific, so cover both meanings: the
      --  mode bit on POSIX, the extension on Windows. See Support.Honours_Executable_Bit.
      Bat_Path  : constant String := Join (Root, "run.bat");
      Text_Path : constant String := Join (Root, "plain.txt");
      Symlink_Path : constant String := Join (Root, "link-to-plain.adb");
      Executable_Symlink_Path : constant String := Join (Root, "link-to-run.sh");
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Run : Boolean := False;
      Found_Symlink : Boolean := False;
      Found_Executable_Symlink : Boolean := False;
      Symlink_Created : Boolean := False;
      Executable_Symlink_Created : Boolean := False;
   begin
      Reset_Root;
      Write_File (Run_Path, "echo run");
      Write_File (Bat_Path, "@echo run");
      Write_File (Text_Path, "plain");
      GNAT.OS_Lib.Set_Executable (Run_Path);
      Symlink_Created := Create_Symlink ("plain.txt", Symlink_Path);
      Executable_Symlink_Created := Create_Symlink ("run.sh", Executable_Symlink_Path);

      Load := Files.File_System.Load_Directory (Root, Settings);
      Assert (Load.Success, "directory metadata load succeeds");

      for Item of Load.Items loop
         if To_String (Item.Name) = "run.sh" then
            declare
               Permissions : constant String := To_String (Item.Permissions);
            begin
               Found_Run := True;
               if Files_Suite.Support.Honours_Executable_Bit then
                  Assert
                    (Item.Kind = Files.Types.Executable_Item,
                     "the executable bit affects item kind");
               else
                  Assert
                    (Item.Kind /= Files.Types.Executable_Item,
                     "a chmod +x .sh is not an executable on a host that runs by extension");
               end if;
               Assert (Item.Modified_Available, "modified timestamp is available");
               Assert (Item.Size_Available, "file size is available");
               if Item.Creation_Available then
                  Assert
                    (Item.Creation_Time >= Ada.Calendar.Time_Of (1970, 1, 1),
                     "creation timestamp is populated when the filesystem reports it");
               else
                  Assert
                    (Item.Creation_Time = Ada.Calendar.Time_Of (1901, 1, 1),
                     "missing creation timestamp keeps deterministic sentinel");
               end if;
               Assert (Permissions'Length = 3, "permission metadata has stable rwx shape");
               if Files_Suite.Support.Honours_Executable_Bit then
                  Assert (Permissions (3) = 'x', "executable permission is captured");
               end if;
            end;
         elsif To_String (Item.Name) = "run.bat" then
            --  The other meaning of executable: no bit was ever set on this file.
            if not Files_Suite.Support.Honours_Executable_Bit then
               Assert
                 (Item.Kind = Files.Types.Executable_Item,
                  "a .bat is an executable on a host that runs by extension");
               Assert
                 (To_String (Item.Permissions) (3) = 'x',
                  "and it is reported as executable in its permissions");
            end if;
         elsif To_String (Item.Name) = "plain.txt" then
            Assert (To_String (Item.Permissions)'Length = 3, "regular file permissions are captured");
         elsif To_String (Item.Name) = "link-to-plain.adb" then
            Found_Symlink := True;
            Assert (Item.Kind = Files.Types.Symlink_Item, "symlink metadata affects item kind");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "inode/symlink",
               "real symlink directory item ignores extension mappings");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Icon_Id),
               "link",
               "real symlink directory item uses link icon");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "symlink.target|plain.txt",
               "real symlink directory item records target metadata");
         elsif To_String (Item.Name) = "link-to-run.sh" then
            Found_Executable_Symlink := True;
            Assert
              (Item.Kind = Files.Types.Symlink_Item,
               "executable symlink metadata keeps symlink kind");
            Files_Suite.Support.Assert_Equal
              (To_String (Item.Filetype),
               "inode/symlink",
               "executable symlink filetype wins before executable metadata");
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "symlink.target|run.sh",
               "executable symlink records target metadata");
         end if;
      end loop;

      Assert (Found_Run, "executable item was loaded");
      if Symlink_Created then
         Assert (Found_Symlink, "symlink item was loaded");
      end if;
      if Executable_Symlink_Created then
         Assert (Found_Executable_Symlink, "executable symlink item was loaded");
      end if;
   end Test_Executable_And_Symlink_Metadata;
