separate (Files_Suite.Model)
   procedure Test_History_Retire_Drain (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Dest     : constant String := Join (Root, "replaced.txt");
      Entry_At : constant String := Join (Root, "history-entry");
      Backup   : Files.Types.UString;
      Result   : Files.File_System.Mutation_Result;
      Recorded : Boolean;
      --  Restores what the test changes, on failure too.
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_History_Retire_Drain",
            "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Dest, "original");
      --  A native backend keeps a replaced original in a private recovery
      --  folder that only the undo entry referencing it can restore.
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "windows");
      Result := Files.File_System.Preserve_For_Replace (Dest, Backup);
      Assert (Result.Success, "Replace keeps the original");
      Assert (Files.File_System.Is_Recovery_Payload (To_String (Backup)),
              "the kept original is a recovery payload");

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
      end;
      Files_Suite.Support.Assert_Equal
        (Natural (Files.Model.Undo_History (Model).Length), 200,
         "the model trims its undo stack to the depth cap");
      Assert (Ada.Directories.Exists (To_String (Backup)),
              "a model-only history mutation leaves the retired payload on disk");

      Files.Operations.Settle_History (Model);
      Assert (not Ada.Directories.Exists (To_String (Backup)),
              "settling the history deletes the payload its retired entry held");
   end Test_History_Retire_Drain;
