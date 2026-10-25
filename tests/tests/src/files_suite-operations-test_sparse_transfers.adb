with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Sparse_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Prepare (Path : System.Address; Mixed : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_sparse_prepare";
      function Verify (Path : System.Address; Mixed : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_sparse_check";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "sparse");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "sparse");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
      end Cleanup;
      procedure Check (Path : String; Mixed : Interfaces.C.int) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Verify (Name'Address, Mixed) = 1,
                 "sparse transfers retain every byte and the trailing hole without allocating the logical size");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Sparse_Transfers", "needs Linux");
         return;
      end if;
      Remote.Create ("files-test-sparse-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Sparse_Transfers", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      for Background in Boolean loop
         for Mixed in Interfaces.C.int range 0 .. 1 loop
            Reset_Root;
            Ada.Directories.Create_Directory (Parent);
            declare
               Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
            begin
               Assert (Prepare (Name'Address, Mixed) = 1, "prepare an all-hole or mixed sparse file");
            end;
            Check (Source, Mixed);
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Operations.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Source));
            Step := Complete_Operation
              (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "copy a sparse file");
            Check (Dest, Mixed);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "Undo a sparse copy");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal (Step.Status, Files.Operations.Operation_Success, "Redo a sparse copy");
            Check (Dest, Mixed);
            Mutation := Files.File_System.Rename_Item (Dest, Join (Remote.Path, "moved"));
            Assert (Mutation.Success, "move a sparse file across filesystems");
            Check (Join (Remote.Path, "moved"), Mixed);
            Mutation := Files.File_System.Rename_Item
              (Join (Remote.Path, "moved"), Dest,
               Files.File_Identities.Token (Join (Remote.Path, "moved")));
            Assert (Mutation.Success, "restore a sparse file through the guarded history path");
            Check (Dest, Mixed);
            Check (Source, Mixed);
         end loop;
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Sparse_Transfers;
