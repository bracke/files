with Files.IO.Fs_Primitives;
with Files.File_System.Trash;
with Files_Suite.Volumes;
with Files_Suite.Support.Guards;
separate (Files_Suite.Trash)
   --  With the Finder's layout (the ~/.Trash backend), an item on another
   --  volume goes to that volume's .Trashes/<uid> -- but only when the
   --  .Trashes there is the system's: root's, sticky. One anybody could have
   --  made is not trusted, and the item is copied to the home trash, as the
   --  freedesktop .Trash is refused when it is not the administrator's.
   --  Where the volume has a .Trashes already (a macOS runner's may), the
   --  test checks the answer for that one instead of making a stand-in.
   procedure Test_Finder_Volume_Trash_Needs_The_Systems_Trashes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote      : Files_Suite.Volumes.Remote_Directory;
      Mac_Home    : constant String := Root & "_finder_volume_home";
      Environment : Files_Suite.Support.Guards.Environment_Guard;
      Made        : Unbounded_String;
      Id          : Natural := 0;

      --  The .Trashes this test made goes, however the test ends.
      procedure Clean is
      begin
         if Length (Made) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Made));
            Made := Null_Unbounded_String;
         end if;
         Project_Tools.Files.Delete_Tree (Mac_Home);
      end Clean;
   begin
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Guards.Save (Environment, "HOME");
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TEST_VOLUME_TRASH");
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Files_Suite.Support.Skip
           ("Test_Finder_Volume_Trash_Needs_The_Systems_Trashes", "Windows has no Finder volume trash");
         return;
      end if;
      Reset_Root;
      Remote.Create ("files-test-finder-trash-");
      if Remote.Path = "" or else not Hostkit.Process.Current_User_Id (Id) then
         Files_Suite.Support.Skip
           ("Test_Finder_Volume_Trash_Needs_The_Systems_Trashes", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      declare
         Top     : constant String :=
           Ada.Directories.Containing_Directory (Files_Suite.Volumes.Volume_Trash_Of (Remote.Path));
         Trashes : constant String := Join (Top, ".Trashes");
         Own     : constant String := Join (Trashes, Ada.Strings.Fixed.Trim (Natural'Image (Id), Ada.Strings.Left));
         Item    : constant String := Join (Remote.Path, "finder-item.txt");
         Trashed : Files.Types.UString;
         Result  : Files.File_System.Mutation_Result;
         --  Whether the .Trashes there is the system's (root's, sticky):
         --  then the item goes into it, else to the home trash.
         Systems : Boolean := False;
      begin
         if Files.IO.Fs_Primitives.Entry_Is_Absent (Trashes) then
            Ada.Directories.Create_Path (Own);
            Made := To_Unbounded_String (Trashes);
            --  Sticky and open to everyone, as the system makes it: only who
            --  owns it tells this one from the system's.
            Assert (Hostkit.Metadata.Set_Permissions (Trashes, 8#1777#), "the stand-in .Trashes is made sticky");
            Assert (Hostkit.Metadata.Set_Permissions (Own, 8#700#), "and its user folder private");
         else
            declare
               use type Interfaces.Unsigned_64;
               Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Trashes);
            begin
               Systems := Revision.Available and then Revision.User_Id = 0 and then (Revision.Mode and 8#1000#) /= 0;
            end;
         end if;

         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos-home");
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Mac_Home);
         Ada.Environment_Variables.Set ("FILES_TEST_VOLUME_TRASH", "on");
         Project_Tools.Files.Delete_Tree (Mac_Home);
         Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));

         Write_File (Item, "finder");
         Result := Files.File_System.Trash.Move_To_Trash (Item, Trashed);
         Assert (Result.Success, "an item on another volume is trashed");
         if Systems then
            Files_Suite.Support.Assert_Equal
              (Ada.Directories.Containing_Directory (To_String (Trashed)), Own,
               "the system's .Trashes is used: the item goes to its folder for this user");
            Assert (Files.File_System.Trash.Is_Volume_Trash_Item (To_String (Trashed)),
                    "and counts as a volume trash item");
         else
            Files_Suite.Support.Assert_Equal
              (Ada.Directories.Containing_Directory (To_String (Trashed)),
               Join (Mac_Home, ".Trash"),
               "a .Trashes the system did not make is not used: the item goes to the home trash");
            Assert (not Ada.Directories.Exists (Join (Own, "finder-item.txt")), "nothing went into it");
            Assert (not Files.File_System.Trash.Is_Volume_Trash_Item (Join (Own, "anything")),
                    "and nothing in it counts as a trash item");
         end if;
         Assert
           (Files.File_System.Trash.Delete_Trashed_Item (To_String (Trashed)).Success,
            "the trashed item is deleted");
      end;
      Clean;
   exception
      when others =>
         Clean;
         raise;
   end Test_Finder_Volume_Trash_Needs_The_Systems_Trashes;
