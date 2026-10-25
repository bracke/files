with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Read_Only_Directory_Transfers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Paths : Files.Types.String_Vectors.Vector;
      procedure Remove (Path : String) is
         Result : constant Files.File_System.Mutation_Result := Files.File_System.Delete_Created_Entry
           (Path, Files.File_Identities.Token (Path), Files.File_System.Tree_Revision (Path));
      begin
         Assert (Result.Success, "clean up the owned read-only tree");
      end Remove;
      procedure Cleanup is
      begin
         Files.Model.Clear_Paste_Execution (Model);
         Files.Refresh_Jobs.Cancel (Model);
         if Ada.Directories.Exists (Source) then
            Remove (Source);
         end if;
         if Ada.Directories.Exists (Join (Root, "copy")) then
            Remove (Join (Root, "copy"));
         end if;
         if Remote.Path /= "" and then Ada.Directories.Exists (Remote.Path) then
            Remove (Remote.Path);
         end if;
      end Cleanup;
      procedure Check (Path : String) is
      begin
         Assert
           (Metadata_Mode_Of (Path) = 8#555#,
            "publication and history preserve root, child directory and file permissions: root mode");
         Assert
           (Metadata_Mode_Of (Join (Path, "locked")) = 8#555#,
            "publication and history preserve root, child directory and file permissions: child directory mode");
         Assert
           (Metadata_Mode_Of (Join (Path, "locked/child")) = 8#444#,
            "publication and history preserve root, child directory and file permissions: file mode");
         Assert
           (File_Has_Bytes (Join (Path, "locked/child"), "read-only bytes"),
            "publication and history preserve root, child directory and file permissions: file bytes");
      end Check;
      procedure Check_Backups (Parent : String) is
         Listing : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Parent, Settings);
      begin
         for Item of Listing.Items loop
            declare
               Name : constant String := To_String (Item.Name);
            begin
               Assert (Name'Length < 16 or else Name (Name'First .. Name'First + 15) /= ".files-recovery-",
                       "committed moves remove their private read-only source backups");
            end;
         end loop;
      end Check_Backups;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Read_Only_Directory_Transfers", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      Remote.Create ("files-test-read-only-move-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Read_Only_Directory_Transfers", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      for Background in Boolean loop
         Reset_Root;
         Ada.Directories.Create_Path (Join (Source, "locked"));
         Write_Binary_File (Join (Source, "locked/child"), "read-only bytes");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked/child"), 8#444#).Success,
                 "protect the source file");
         Assert (Files.File_System.Set_Permissions (Join (Source, "locked"), 8#555#).Success,
                 "protect the child source directory");
         Assert (Files.File_System.Set_Permissions (Source, 8#555#).Success, "protect the source root");
         Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
         Assert (Mutation.Success, "publish a copy of a read-only directory");
         Check (Source);
         Check (Join (Root, "copy"));
         Remove (Join (Root, "copy"));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, Background);
         Paths.Clear;
         Paths.Append (To_Unbounded_String (Source));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To
              (Model, Settings, Paths, Remote.Path, Files.File_System.Drop_Move));
         Await_View (Model, Settings);
         Assert (Step.Status = Files.Operations.Operation_Success and then not Ada.Directories.Exists (Source),
                 "move a read-only root across filesystems");
         for Cycle in 1 .. 2 loop
            Check (Join (Remote.Path, "source"));
            Check_Backups (Root);
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo a read-only directory move");
            Check (Source);
            Check_Backups (Remote.Path);
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Redo a read-only directory move");
         end loop;
         Remove (Join (Remote.Path, "source"));
      end loop;
      Cleanup;
   exception
      when others =>
         Cleanup;
         raise;
   end Test_Read_Only_Directory_Transfers;
