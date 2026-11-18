with Files.Fs_Primitives;
with Files.File_System.Trash;
with Files_Suite.Support.Guards;
separate (Files_Suite.Trash)
   --  A freedesktop trash names its payloads for itself ("notes.txt.2" for a
   --  second "notes.txt"); the trash view lists each under the name it had,
   --  so its type follows that name, while its path stays the payload's.
   procedure Test_Trash_View_Shows_Original_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Mutation : Files.File_System.Mutation_Result;
      First, Second : Unbounded_String;
      Load     : Files.File_System.Directory_Load_Result;
      Named    : Natural := 0;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Guards.Environment_Guard;
   begin
      Files_Suite.Support.Guards.Save (Environment, "XDG_DATA_HOME");
      Files_Suite.Support.Guards.Save (Environment, "FILES_TRASH_BACKEND");
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Path (Join (Root, "a"));
      Ada.Directories.Create_Path (Join (Root, "b"));
      Write_Binary_File (Join (Join (Root, "a"), "notes.txt"), "first");
      Write_Binary_File (Join (Join (Root, "b"), "notes.txt"), "second");
      Mutation := Files.File_System.Trash.Move_To_Trash (Join (Join (Root, "a"), "notes.txt"), First);
      Assert (Mutation.Success, "the first notes.txt is trashed");
      Mutation := Files.File_System.Trash.Move_To_Trash (Join (Join (Root, "b"), "notes.txt"), Second);
      Assert (Mutation.Success, "the second notes.txt is trashed");
      Assert (Files.Fs_Primitives.Leaf_Text (To_String (Second)) /= "notes.txt",
              "the trash names the second payload for itself");

      Load := Files.File_System.Load_Directory (Files.File_System.Trash.Trash_Files_Directory, Settings);
      Assert (Load.Success, "the trash view loads");
      for Item of Load.Items loop
         Assert (To_String (Item.Name) = "notes.txt",
                 "a payload is listed under the name it had: " & To_String (Item.Name));
         Assert (To_String (Item.Full_Path) = To_String (First) or else To_String (Item.Full_Path) = To_String (Second),
                 "its path is still the payload's");
         Files_Suite.Support.Assert_Equal
           (To_String (Item.Filetype), "text/plain", "its type follows the name it had");
         Named := Named + 1;
      end loop;
      Files_Suite.Support.Assert_Equal (Named, 2, "both payloads are listed");
   end Test_Trash_View_Shows_Original_Names;
