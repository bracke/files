with Files.File_System.Trash;
with Files.File_System.Testing;
separate (Files_Suite.Trash)
   procedure Test_Macos_Home_Trash_Fallback (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Mac_Home     : constant String := Root & "_mac_home";

      procedure Check is
         Mutation     : Files.File_System.Mutation_Result;
      begin
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "macos-home");
         Project_Tools.Files.Delete_Tree (Mac_Home);
         Ada.Directories.Create_Path (Join (Mac_Home, ".Trash"));
         Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         Ada.Environment_Variables.Set ("HOME", Mac_Home);
         Write_File (Join (Root, "mac-trash.txt"));
         Mutation := Files.File_System.Trash.Move_To_Trash (Join (Root, "mac-trash.txt"));
         Assert (Mutation.Success, "macOS-style home trash fallback moves files");
         Assert
           (Files.File_System.Trash.Trash_Backend_Of_Current_Environment = Files.File_System.Trash.Trash_Macos_Home,
            "trash backend reports macOS-style home trash when present");
         Assert
           (Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "mac-trash.txt")),
            "macOS-style home trash stores the file directly under ~/.Trash");
         Assert
           (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "files")),
            "macOS-style home trash does not create a freedesktop files/ subdirectory");
         Assert
           (not Ada.Directories.Exists (Join (Join (Mac_Home, ".Trash"), "info")),
            "macOS-style home trash does not create a freedesktop info/ subdirectory");

         --  Undo puts an item back out of ~/.Trash: the history knows where
         --  it came from, as the Finder's layout keeps no record of its own.
         declare
            Item     : constant String := Join (Root, "mac-undo.txt");
            Trashed  : Files.Types.UString;
         begin
            Write_File (Item, "back again");
            Mutation := Files.File_System.Trash.Move_To_Trash (Item, Trashed);
            Assert (Mutation.Success, "trashed to be put back");
            Assert (not Files.File_System.Trash.Is_Volume_Trash_Item (To_String (Trashed)),
                    "~/.Trash is the home trash, not a volume's");
            declare
               Identity : constant String := Files.File_Identities.Token (To_String (Trashed));
            begin
               Assert
                 (Files.File_System.Trash.Restore_From_Trash (To_String (Trashed), Identity, Item).Success,
                  "Undo restores an item from the macOS-style home trash");
            end;
            Assert (Ada.Directories.Exists (Item) and then not Ada.Directories.Exists (To_String (Trashed)),
                    "it is back where it was, and gone from the trash");
            Mutation := Files.File_System.Trash.Move_To_Trash (Item, Trashed);
            Assert (Mutation.Success, "trashed again");
            Assert (not Files.File_System.Trash.Restore_From_Trash (To_String (Trashed)).Success,
                    "with nothing that says where it came from, it is not restored");
            Assert (Files.File_System.Trash.Delete_Trashed_Item (To_String (Trashed)).Success,
                    "and is deleted from the trash");
            Assert (not Ada.Directories.Exists (To_String (Trashed)), "for good");
         end;
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Macos_Home_Trash_Fallback;
