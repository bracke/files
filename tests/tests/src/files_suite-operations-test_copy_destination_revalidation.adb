separate (Files_Suite.Operations)
   procedure Test_Copy_Destination_Revalidation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Child : constant String := Join (Source, "child");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Plans : Files.File_System.Drop_Import_Result;
      procedure Check_Source is
      begin
         Load := Files.File_System.Load_Directory (Child, Settings);
         Assert (Load.Success and then Load.Items.Is_Empty,
                 "refusing a descendant copy leaves no staging or recursive copies");
         Assert (File_Has_Bytes (Join (Source, "original"), "original bytes"), "the source is unchanged");
      end Check_Source;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Copy_Destination_Revalidation", "needs Linux");
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Child);
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Join (Source, "original"), "original bytes");
         Mutation := Files.File_System.Copy_Tree (Source, Join (Child, "copy"));
         Assert (not Mutation.Success, "the copy operation itself refuses its own descendants");
         Check_Source;
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "make the original copy");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "Undo the copy");
         Ada.Directories.Delete_Directory (Parent);
         Assert (Hostkit.Fs.Create_Link (Child, Parent), "redirect the destination parent into the source");
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Plans := Files.File_System.Plan_Drop_Import
           (Paths, Parent, Files.File_System.Drop_Copy);
         Assert
           (not Plans.Success
            and then To_String (Plans.Error_Key) = "error.drop.into_self",
            "planning resolves a destination alias into the source tree");

         declare
            Stay : constant String := Join (Child, "stay.txt");
         begin
            Write_Binary_File (Stay, "stay");
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Stay));
            Plans := Files.File_System.Plan_Drop_Import
              (Paths, Parent, Files.File_System.Drop_Move);
            Assert
              (Plans.Success, "a move through an alias to the same directory is planned as a no-op: planned");
            Files_Suite.Support.Assert_Equal
              (Natural (Plans.Plans.Length),
               1,
               "a move through an alias to the same directory is planned as a no-op: plan count");
            Files_Suite.Support.Assert_Equal
              (To_String (Plans.Plans.First_Element.Destination_Path),
               Stay,
               "a move through an alias to the same directory is planned as a no-op: destination");
            Mutation := Files.File_System.Execute_Drop_Import (Plans.Plans);
            Assert
              (Mutation.Success, "the aliased same-directory move keeps the original name and bytes: succeeds");
            Assert
              (File_Has_Bytes (Stay, "stay"),
               "the aliased same-directory move keeps the original name and bytes: bytes");
            Assert
              (not Ada.Directories.Exists (Join (Child, "stay 2.txt")),
               "the aliased same-directory move keeps the original name and bytes: no renamed copy");
            Ada.Directories.Delete_File (Stay);
         end;
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Assert (not Mutation.Success, "direct copies resolve destination-parent aliases");
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Failed and then Files.Model.Redo_Available (Model),
                 "Redo refuses a newly redirected descendant and retains retryable history");
         Check_Source;
         Assert (Hostkit.Fs.Delete_Link (Parent), "remove the destination alias");
         Ada.Directories.Create_Directory (Parent);
         Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success
                 and then File_Has_Bytes (Join (Dest, "original"), "original bytes"),
                 "Redo can be retried after repairing the destination");
      end loop;
   exception
      when others =>
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         raise;
   end Test_Copy_Destination_Revalidation;
