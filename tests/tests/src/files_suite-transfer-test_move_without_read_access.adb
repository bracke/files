separate (Files_Suite.Transfer)
   procedure Test_Move_Without_Read_Access (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : aliased Files.Model.Window_Model;
      Paste : Files_Suite.Support.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "source");
      Destination : constant String := Join (Root, "destination");
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
   begin
      --  Mode 0 is an empty DACL on Windows: nothing may be read, and only
      --  the folder's own FILE_DELETE_CHILD lets the entry be renamed away,
      --  as a POSIX folder's write bit does.
      for Directory_Move in Boolean loop
         Reset_Root;
         if Directory_Move then
            Ada.Directories.Create_Directory (Source);
            Write_Binary_File (Join (Source, "child"), "private bytes");
            Mutation := Files.File_System.Set_Permissions (Join (Source, "child"), 0);
         else
            Write_Binary_File (Source, "private bytes");
            Mutation := Files.File_System.Set_Permissions (Source, 0);
         end if;
         Assert (Mutation.Success, "prepare an unreadable move source");
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, False);
         Actions.Clear;
         Actions.Append (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Destination), False, False));
         Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Move, False);
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "same-device paste moves an unreadable entry and retains Undo: status, "
            & To_String (Step.Error_Key)
            & (if Step.Status = Files.Operations.Operation_Success then ""
               else Files_Suite.Support.Access_Report (Source, Tree => True)));
         Assert (not Ada.Directories.Exists (Source),
                 "same-device paste moves an unreadable entry and retains Undo: source moved");
         Assert (Ada.Directories.Exists (Destination),
                 "same-device paste moves an unreadable entry and retains Undo: destination exists");
         Assert (Files.Model.History.Undo_Available (Model),
                 "same-device paste moves an unreadable entry and retains Undo: Undo recorded");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Source),
                 "Undo returns the unreadable entry by identity");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then Ada.Directories.Exists (Destination),
                 "Redo moves the unreadable entry by identity");
         Mutation := Files.File_System.Set_Permissions
           ((if Directory_Move then Join (Destination, "child") else Destination), 8#644#);
      end loop;
   end Test_Move_Without_Read_Access;
