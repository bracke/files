separate (Files_Suite.Operations)
   procedure Test_Rename_Trash_Delete_Read_Only_Cause (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Environment : Files_Suite.Support.Environment_Guard;
      Locked : constant String := Join (Root, "locked");
      Item : constant String := Join (Locked, "item.txt");
      Mutation : Files.File_System.Mutation_Result;
   begin
      Environment.Save ("XDG_DATA_HOME");
      Environment.Save ("FILES_TRASH_BACKEND");
      Reset_Root;
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Join (Root, "xdg"));
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Ada.Directories.Create_Directory (Locked);
      Write_Binary_File (Item, "item bytes");
      if not Lock_Directory (Locked) then
         Unlock_Directory (Locked);
         Files_Suite.Support.Skip
           ("Test_Rename_Trash_Delete_Read_Only_Cause", "a read-only directory does not refuse writes here");
         return;
      end if;
      Mutation := Files.File_System.Rename_Item (Item, Join (Locked, "renamed.txt"));
      Assert (not Mutation.Success, "a read-only folder refuses a rename");
      Assert_Equal (To_String (Mutation.Error_Key), "error.io.denied", "the refused rename says permission was denied");
      Mutation := Files.File_System.Rename_Item
        (Item, Join (Locked, "renamed.txt"), Files.File_Identities.Token (Item));
      Assert_Equal
        (To_String (Mutation.Error_Key), "error.io.denied", "the refused recorded rename says permission was denied");
      Mutation := Files.File_System.Move_To_Trash (Item);
      Assert (not Mutation.Success, "a read-only folder refuses to give up an item to the trash");
      Assert_Equal (To_String (Mutation.Error_Key), "error.io.denied", "the refused trash says permission was denied");
      Mutation := Files.File_System.Delete_Permanently (Item);
      Assert (not Mutation.Success, "a read-only folder refuses a permanent delete");
      Assert_Equal (To_String (Mutation.Error_Key), "error.io.denied", "the refused delete says permission was denied");
      Unlock_Directory (Locked);
      Assert (File_Has_Bytes (Item, "item bytes")
              and then not Ada.Directories.Exists (Join (Locked, "renamed.txt")),
              "every refused mutation leaves the item where it was");

      --  Failures the operation names itself keep their keys.
      Mutation := Files.File_System.Rename_Item (Join (Locked, "absent.txt"), Join (Locked, "other.txt"));
      Assert_Equal (To_String (Mutation.Error_Key), "error.rename.source_missing", "a missing source keeps its key");
      Mutation := Files.File_System.Delete_Permanently (Join (Locked, "absent.txt"));
      Assert_Equal (To_String (Mutation.Error_Key), "error.path.missing",
                    "deleting a vanished item says the path is missing, not a rename error");
   exception
      when others =>
         Unlock_Directory (Locked);
         raise;
   end Test_Rename_Trash_Delete_Read_Only_Cause;
