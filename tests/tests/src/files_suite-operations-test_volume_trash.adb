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

      --  The top of Path's filesystem: its highest ancestor on its device.
      function Volume_Top (Path : String) return String is
         Known  : Boolean;
         Device : constant Long_Long_Integer := Hostkit.Metadata.Device_Id (Path, Known);
         Top    : Unbounded_String := To_Unbounded_String (Path);
      begin
         loop
            declare
               Up : constant String := Ada.Directories.Containing_Directory (To_String (Top));
               Up_Known : Boolean;
            begin
               exit when Up = To_String (Top)
                 or else Hostkit.Metadata.Device_Id (Up, Up_Known) /= Device
                 or else not Up_Known;
               Top := To_Unbounded_String (Up);
            end;
         end loop;
         return To_String (Top);
      exception
         when Ada.Directories.Use_Error => return To_String (Top);
      end Volume_Top;

      --  This user's numeric id, as volume trash names carry it.
      function User_Id return String is
         Id : Natural := 0;
      begin
         Assert (Hostkit.Process.Current_User_Id (Id), "the user has a numeric id");
         return Ada.Strings.Fixed.Trim (Natural'Image (Id), Ada.Strings.Left);
      end User_Id;

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
         Volume_Base := To_Unbounded_String (Join (Volume_Top (Remote.Path), ".Trash-" & User_Id));
         Result := Files.File_System.Move_To_Trash (Volume_Item, Trashed);
         Assert (Result.Success, "an item on another volume is trashed");
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
      end;
      Clean;
   exception
      when others =>
         Clean;
         raise;
   end Test_Volume_Trash;
