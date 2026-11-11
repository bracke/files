with Files.Fs_Primitives;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Fixed;
with Files.UTF8;
separate (Files_Suite.Operations)
   --  A name too long for the trash to add ".trashinfo" or a counter to is
   --  still trashed, under a shortened name, and restored under its own.
   procedure Test_Trash_Long_Name (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      --  245 bytes: a leaf the filesystem stores, but not with ".trashinfo"
      --  added. 121 ASCII bytes then two-byte letters, so the cut to 230
      --  bytes before the extension lands inside a letter and must back off.
      Long_Name : constant String :=
        Ada.Strings.Fixed."*" (121, 'x')
        & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Ada.Strings.Wide_Wide_Fixed."*" (60, "ж"))
        & ".txt";
      Original  : constant String := Join (Root, Long_Name);
      Mac_Home  : constant String := Root & "_mac_home";

      --  The fixture is reached through Hostkit: with the folder in front of
      --  it the name passes Windows' 260-character limit, where GNAT's own
      --  calls stop. The name itself fits there: 185 UTF-16 units of 255.
      function Present (Path : String) return Boolean is (Files.Fs_Primitives.Entry_Exists (Path));

      --  Remove the macOS home, long names and all, past that limit too:
      --  With_Trash_Environment's own cleanup reads through GNAT.
      procedure Clear_Mac_Home is
      begin
         if Present (Mac_Home) then
            Assert
              (Hostkit.Fs."=" (Hostkit.Fs.Delete_Tree_No_Follow (Mac_Home), Hostkit.Fs.Tree_Deleted),
               "the macOS home trash fixture is removed");
         end if;
      end Clear_Mac_Home;

      procedure Check is
         Trashed : Files.Types.UString;
         Leaf    : Unbounded_String;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         --  Beside Root, where With_Trash_Environment cleans up: not the
         --  user's own trash, and named on every host (Windows sets no HOME).
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Root & "_xdg_data");
         Write_Long_Path_File (Original, "long");
         Assert (Files.File_System.Move_To_Trash (Original, Trashed).Success,
                 "a file with a 245-byte name goes to the trash");
         Assert (not Present (Original), "it left its folder");
         Leaf := To_Unbounded_String (Files.Fs_Primitives.Leaf_Text (To_String (Trashed)));
         Files_Suite.Support.Assert_Equal
           (Length (Leaf), 233, "it is kept under a name cut to fit, one byte backed off a split letter");
         Assert (Files.Types.Starts_With (To_String (Leaf), Ada.Strings.Fixed."*" (121, 'x'))
                 and then Ada.Directories.Extension (To_String (Leaf)) = "txt",
                 "the shortened name keeps its start and extension");
         Assert (Files.UTF8.Is_Valid (To_String (Leaf)), "the cut ends a whole character");
         Assert (Files.File_System.Restore_From_Trash (To_String (Trashed)).Success,
                 "it is restored");
         Assert (Present (Original), "under its own name");

         --  The macOS home trash keeps no info file: a long name goes in as
         --  it is, and is cut only when a second one needs a counter.
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos-home");
         Clear_Mac_Home;
         Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Mac_Home);
         Assert (Files.File_System.Move_To_Trash (Original).Success, "the first goes to the home trash");
         Assert (Present (Join (Join (Mac_Home, ".Trash"), Long_Name)), "under its own name");
         Write_Long_Path_File (Original, "again");
         Assert (Files.File_System.Move_To_Trash (Original).Success,
                 "a second of the same long name goes too, cut to make room for its counter");
         Clear_Mac_Home;
      exception
         when others =>
            Clear_Mac_Home;
            raise;
      end Check;
   begin
      Reset_Root;
      With_Trash_Environment (Check'Access);
   end Test_Trash_Long_Name;
