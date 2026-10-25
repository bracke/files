separate (Files_Suite.Operations)
   procedure Test_Background_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "worker-source");
      Dest_Dir : constant String := Join (Root, "worker-dest");
      Dest     : constant String := Join (Dest_Dir, "worker-source");
      Action   : Files.Paste.Resolved_Action;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Job      : Files.Transfer_Jobs.Session;
      Finished : Boolean := False;
      Outcome  : Files.Transfer_Jobs.Job_Result;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dest_Dir);
      Write_Binary_File (Source, [1 .. 262_144 => 'w']);
      Action := (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False);
      Files.Transfer_Jobs.Start (Job, Action, Files.File_System.Drop_Copy);
      declare
         Other_Owner : constant Files.Transfer_Jobs.Session := Job;
      begin
         Files.Transfer_Jobs.Reset (Job);
         for Attempt in Files_Suite.Support.Polling loop
            Files.Transfer_Jobs.Poll (Other_Owner, Finished, Outcome);
            exit when Finished;
         end loop;
         Assert (Finished and then Outcome.Mutation.Success, "a copied session keeps its worker alive");
      end;
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Dest),
         Project_Tools.Files.Read_Raw_File (Source),
         "the worker copies every byte");

      Ada.Directories.Delete_File (Dest);
      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Actions.Append (Action);
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      for Attempt in Files_Suite.Support.Polling loop
         Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Paste_Execution_Is_Active (Model);
      end loop;
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the UI collects a completed background action");
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "background completion reports success");
      Assert (Files.Model.Undo_Available (Model), "background writes record undo on the UI thread");
      Step := Complete_Operation
                       (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (not Ada.Directories.Exists (Dest), "undo removes a background copy");

      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Files.Operations.Cancel_Paste_Execution (Model);
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "cancellation before launch finalizes immediately");
      Assert (not Ada.Directories.Exists (Dest), "a cancelled background action writes nothing");

      --  Cancellation of an already-started worker must never publish a partial
      --  file. A worker that won the race may legitimately finish the whole copy.
      declare
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : constant Ada.Streams.Stream_Element_Array (1 .. 65_536) := [others => 42];
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Source);
         for Chunk in 1 .. 128 loop
            Ada.Streams.Stream_IO.Write (File, Buffer);
         end loop;
         Ada.Streams.Stream_IO.Close (File);
      end;
      Files.Transfer_Jobs.Start (Job, Action, Files.File_System.Drop_Copy);
      Files.Transfer_Jobs.Cancel (Job);
      for Attempt in Files_Suite.Support.Polling loop
         Files.Transfer_Jobs.Poll (Job, Finished, Outcome);
         exit when Finished;
      end loop;
      Assert (Finished, "an already-started worker responds to cancellation");
      Assert (Ada.Directories.Size (Source) = 8_388_608, "worker cancellation retains the complete source");
      if Outcome.Mutation.Success then
         Assert (Ada.Directories.Size (Dest) = 8_388_608, "a worker completing before cancellation keeps a full copy");
      else
         Assert (Outcome.Cancelled, "an interrupted worker reports cancellation");
         Assert (not Ada.Directories.Exists (Dest), "an interrupted worker removes its incomplete output");
      end if;
      Files.Transfer_Jobs.Reset (Job);
   end Test_Background_Transfers;
