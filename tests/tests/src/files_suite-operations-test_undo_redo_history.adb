separate (Files_Suite.Operations)
   procedure Test_Undo_Redo_History (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      A0     : constant String := Join (Root, "a0.txt");
      A1     : constant String := Join (Root, "a1.txt");
      B0     : constant String := Join (Root, "b0.txt");
      B1     : constant String := Join (Root, "b1.txt");
      B2     : constant String := Join (Root, "b2.txt");
      C0     : constant String := Join (Root, "c0.txt");
      C1     : constant String := Join (Root, "c1.txt");
      Load   : Files.File_System.Directory_Load_Result;
      Model  : Files.Model.Window_Model;
      Result : Files.Operations.Operation_Result;

      procedure Rename (From_Name, To_Name : String) is
         Step : Files.Operations.Operation_Result;
      begin
         Select_Name (Model, From_Name);
         Files.Model.Toggle_Rename (Model);
         Files.Model.Set_Rename_Text (Model, To_Name);
         Step := Files.Operations.Commit_Rename (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "rename " & From_Name & " to " & To_Name & " commits");
      end Rename;
   begin
      Reset_Root;
      Write_File (A0, "A");
      Write_File (B0, "B");
      Write_File (C0, "C");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);

      --  Three undoable operations are pushed in order.
      Rename ("a0.txt", "a1.txt");
      Rename ("b0.txt", "b1.txt");
      Rename ("c0.txt", "c1.txt");
      Assert (Files.Model.Undo_Available (Model), "undo is available after three renames");
      Assert (not Files.Model.Redo_Available (Model), "no redo is pending before undoing");

      --  Undo unwinds last-in-first-out: C, then B, then A.
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "first undo succeeds");
      Assert
        (Ada.Directories.Exists (C0) and then not Ada.Directories.Exists (C1),
         "the first undo reverses the most recent rename (C)");
      Assert (Ada.Directories.Exists (B1), "earlier renames stay applied after one undo");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "second undo succeeds");
      Assert
        (Ada.Directories.Exists (B0) and then not Ada.Directories.Exists (B1),
         "the second undo reverses B");

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "third undo succeeds");
      Assert
        (Ada.Directories.Exists (A0) and then not Ada.Directories.Exists (A1),
         "the third undo reverses A");
      Assert (not Files.Model.Undo_Available (Model), "the undo stack empties after unwinding all three");
      Assert (Files.Model.Redo_Available (Model), "redo becomes available after undoing");

      --  Redo re-applies forward across all levels: A, then B, then C.
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "first redo succeeds");
      Assert
        (Ada.Directories.Exists (A1) and then not Ada.Directories.Exists (A0),
         "the first redo re-applies A");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "second redo succeeds");
      Assert (Ada.Directories.Exists (B1), "the second redo re-applies B");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "third redo succeeds");
      Assert (Ada.Directories.Exists (C1), "the third redo re-applies C");
      Assert (not Files.Model.Redo_Available (Model), "the redo stack empties after re-applying all three");
      Assert (Files.Model.Undo_Available (Model), "undo is available again after redoing");

      --  undo -> redo -> undo round-trips the current top action.
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "round-trip undo succeeds");
      Assert (Ada.Directories.Exists (C0), "round-trip: undo returns C to its original name");
      Result := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal (Result.Status, Files.Operations.Operation_Success, "round-trip redo succeeds");
      Assert (Ada.Directories.Exists (C1), "round-trip: redo re-applies C");
      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Operations.Operation_Success, "round-trip undo again succeeds");
      Assert (Ada.Directories.Exists (C0), "round-trip: undo again returns C");

      --  A new undoable operation clears the pending redo history.
      Assert (Files.Model.Redo_Available (Model), "redo is still pending before the new operation");
      Rename ("b1.txt", "b2.txt");
      Assert (Ada.Directories.Exists (B2), "the new rename applies");
      Assert (not Files.Model.Redo_Available (Model), "a new operation clears the redo stack");

      declare
         Directory : constant String := Join (Root, "malformed-history");
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Directories.Create_Directory (Directory);
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Join (Directory, "history"));
         String'Output
           (Ada.Streams.Stream_IO.Stream (File), "files-history-1");
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1);
         Files.Model.Undo_Action_Kind'Output
           (Ada.Streams.Stream_IO.Stream (File), Files.Model.Undo_Rename);
         Natural'Output (Ada.Streams.Stream_IO.Stream (File), 1);
         Integer'Output (Ada.Streams.Stream_IO.Stream (File), 1);
         Integer'Output
           (Ada.Streams.Stream_IO.Stream (File), Integer'Last);
         Ada.Streams.Stream_IO.Close (File);
         Assert
           (not Files.History_Journal.Restore (Directory, Model)
            and then Files.Model.Undo_Available (Model),
            "forged history string bounds are rejected without replacing live history");
      end;

      declare
         Write_Directory : constant String := Join (Root, "linked-history-write");
         Read_Directory  : constant String := Join (Root, "linked-history-read");
         Hard_Directory  : constant String := Join (Root, "hard-linked-history-read");
         Source_Directory : constant String := Join (Root, "history-source");
         Victim          : constant String := Join (Root, "history-victim");
         Rejected        : Boolean := False;
      begin
         begin
            Files.History_Journal.Save_Stacks
              ("relative-history-directory",
               Files.Model.Undo_Entry_Vectors.Empty_Vector,
               Files.Model.Undo_Entry_Vectors.Empty_Vector,
               Required => True);
         exception
            when Ada.Directories.Use_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected
            and then not Ada.Directories.Exists ("relative-history-directory"),
            "history snapshots reject relative transport directories");
         Rejected := False;
         Assert
           (not Files.History_Journal.Restore
              (Root & Character'Val (0) & "history-directory", Model),
            "history restore rejects NUL-containing transport directories");

         Ada.Directories.Create_Directory (Write_Directory);
         Write_Binary_File (Victim, "protected history target");
         if Hostkit.Fs.Create_Link
           (Victim, Join (Write_Directory, "history.tmp"))
         then
            begin
               Files.History_Journal.Save_Stacks
                 (Write_Directory,
                  Files.Model.Undo_History (Model),
                  Files.Model.Redo_History (Model),
                  Required => True);
            exception
               when Ada.Directories.Use_Error =>
                  Rejected := True;
            end;
            Assert
              (Rejected and then File_Has_Bytes (Victim, "protected history target"),
               "history snapshots refuse a temporary symlink without truncating its target");
         else
            Files_Suite.Support.Link_Not_Made ("Test_Undo_Redo_History", Files_Suite.Support.Symbolic_Link);
         end if;

         Ada.Directories.Create_Directory (Source_Directory);
         Files.History_Journal.Save_Stacks
           (Source_Directory,
            Files.Model.Undo_Entry_Vectors.Empty_Vector,
            Files.Model.Undo_Entry_Vectors.Empty_Vector,
            Required => True);
         Ada.Directories.Create_Directory (Read_Directory);
         if Hostkit.Fs.Create_Link
           (Join (Source_Directory, "history"), Join (Read_Directory, "history"))
         then
            Assert
              (not Files.History_Journal.Restore (Read_Directory, Model)
               and then Files.Model.Undo_Available (Model),
               "history restore refuses a linked snapshot without replacing live history");
         else
            Files_Suite.Support.Link_Not_Made ("Test_Undo_Redo_History", Files_Suite.Support.Symbolic_Link);
         end if;
         Ada.Directories.Create_Directory (Hard_Directory);
         if Hostkit.Fs.Create_Hard_Link
           (Join (Source_Directory, "history"),
            Join (Hard_Directory, "history"))
         then
            Assert
              (not Files.History_Journal.Restore (Hard_Directory, Model)
               and then Files.Model.Undo_Available (Model),
               "history restore refuses a multiply-linked snapshot without replacing live history");
         else
            Files_Suite.Support.Link_Not_Made ("Test_Undo_Redo_History", Files_Suite.Support.Hard_Link);
         end if;
      end;
   end Test_Undo_Redo_History;
