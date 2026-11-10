with Files.Operations.Testing;
with Project_Tools.Files;
separate (Files_Suite.Model)
   procedure Test_History_Retire_Drain (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Dest     : constant String := Join (Root, "replaced.txt");
      Entry_At : constant String := Join (Root, "history-entry");
      Backup   : Files.Types.UString;
      Rejected : Files.Types.UString;
      Trash_Home : constant String := Root & "_retire_drain_xdg";
      Result   : Files.File_System.Mutation_Result;
      Recorded : Boolean;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
      Reset_Root;
      Project_Tools.Files.Delete_Tree (Trash_Home);
      Ada.Environment_Variables.Set ("XDG_DATA_HOME", Trash_Home);
      Write_Binary_File (Dest, "original");
      --  A native backend keeps a replaced original in a private recovery
      --  folder that only the undo entry referencing it can restore.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "Replace keeps the original");
      Assert (Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "the kept original is a recovery payload");
      Write_Binary_File (Join (Root, "rejected.txt"), "rejected");
      Result := Files.File_System.Preserve_For_Replace (Join (Root, "rejected.txt"), Rejected);
      Assert (Result.Success, "Replace keeps the second original");

      --  The oldest entry references the payload; pushing past the depth cap
      --  through the model alone retires it.
      declare
         From, Payloads : Files.Types.String_Vectors.Vector;
      begin
         From.Append (To_Unbounded_String (Entry_At));
         Payloads.Append (Backup);
         Recorded := Files.Model.Commit_Undo_Record
           (Model,
            (Kind => Files.Model.Undo_Delete_Created, From => From, Redoable => False,
             Restore_Trash => Payloads, others => <>));
         Assert (Recorded, "the model records the payload-carrying entry");
         for Index in 1 .. 200 loop
            Recorded := Files.Model.Commit_Undo_Record
              (Model,
               (Kind => Files.Model.Undo_Delete_Created, From => From, Redoable => False, others => <>));
            Assert (Recorded, "the model records entry" & Index'Image);
         end loop;
         --  An entry that records nothing still carried a preserved original.
         Payloads.Clear;
         Payloads.Append (Rejected);
         Recorded := Files.Model.Commit_Undo_Record
           (Model,
            (Kind => Files.Model.Undo_Delete_Created, Redoable => False,
             Restore_Trash => Payloads, others => <>));
         Assert (not Recorded, "an entry without paths is not recorded");
      end;
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_History (Model).Length), 200,
         "the model trims its undo stack to the depth cap");
      Assert (Ada.Directories.Exists (To_String (Backup)),
              "a model-only history mutation leaves the retired payload on disk");

      --  The trimmed entry could still have been undone and the rejected one
      --  never could be: neither original is deleted, both go to the trash.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      Files.Operations.Testing.Settle_History (Model);
      Assert (not Ada.Directories.Exists (To_String (Backup)),
              "settling the history moves the payload its retired entry held");
      Assert (not Ada.Directories.Exists (To_String (Rejected)),
              "settling the history moves the payload of the unrecorded entry");
      declare
         Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Found_Original, Found_Rejected : Boolean := False;
      begin
         for Item of Files.File_System.Load_Directory (Files.File_System.Trash_Files_Directory, Settings).Items loop
            Found_Original := Found_Original or else File_Has_Bytes (To_String (Item.Full_Path), "original");
            Found_Rejected := Found_Rejected or else File_Has_Bytes (To_String (Item.Full_Path), "rejected");
         end loop;
         Assert (Found_Original, "the trimmed entry's original is in the trash");
         Assert (Found_Rejected, "the unrecorded entry's original is in the trash");
      end;
      Project_Tools.Files.Delete_Tree (Trash_Home);
   end Test_History_Retire_Drain;
