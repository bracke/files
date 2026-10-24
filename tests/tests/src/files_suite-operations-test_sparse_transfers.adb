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
      Remote : Unbounded_String;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
      procedure Check (Path : String; Mixed : Interfaces.C.int) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Verify (Name'Address, Mixed) = 1,
                 "sparse transfers retain every byte and the trailing hole without allocating the logical size");
      end Check;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip
           ("Test_Sparse_Transfers",
            "Hostkit.Host.Current /= Hostkit.Host.Linux or else not Ada.Director...");
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-sparse-move-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Sparse_Transfers", "Length (Remote) = 0");
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
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Paths.Clear;
            Paths.Append (To_Unbounded_String (Source));
            Step := Complete_Operation
              (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "copy a sparse file");
            Check (Dest, Mixed);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Undo a sparse copy");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success, "Redo a sparse copy");
            Check (Dest, Mixed);
            Mutation := Files.File_System.Rename_Item (Dest, Join (To_String (Remote), "moved"));
            Assert (Mutation.Success, "move a sparse file across filesystems");
            Check (Join (To_String (Remote), "moved"), Mixed);
            Mutation := Files.File_System.Rename_Item
              (Join (To_String (Remote), "moved"), Dest,
               Files.File_Identities.Token (Join (To_String (Remote), "moved")));
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
