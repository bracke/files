separate (Files_Suite.Operations)
   procedure Test_Metadata_History_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "metadata-source");
      Held : constant String := Join (Root, "held-source");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Uid, Gid : Natural;
      Available : Boolean;
      procedure Replace_And_Refuse (Forward : Boolean) is
      begin
         Assert (Hostkit.Fs.Move_No_Replace (Source, Held), "retain the metadata history inode");
         Write_Binary_File (Source, "unrelated replacement");
         Mutation := Files.File_System.Set_Permissions (Source, 8#640#);
         Assert (Mutation.Success, "give the replacement independent permissions");
         Step := Complete_Operation (Model, Settings,
           (if Forward then Files.Operations.Redo_Last (Model, Settings)
            else Files.Operations.Undo_Last (Model, Settings)));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Failed,
            "metadata history refuses a replacement without changing its access bits: status");
         Files_Suite.Support.Assert_Equal
           (Metadata_Mode_Of (Source),
            8#640#,
            "metadata history refuses a replacement without changing its access bits: access bits");
         Assert (File_Has_Bytes (Source, "unrelated replacement"),
                 "metadata history refuses a replacement without changing its access bits: content");
         Assert ((if Forward then Files.Model.Redo_Available (Model) else Files.Model.Undo_Available (Model)),
                 "refused metadata history remains retryable");
         Mutation := Files.File_System.Delete_Permanently (Source);
         Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Held, Source),
                 "restore the owned metadata entry");
      end Replace_And_Refuse;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Metadata_History_Identity", "not Files.File_System.Supports_Permissions");
         return;
      end if;
      for Background in Boolean loop
         for Kind in 1 .. 3 loop
            if Kind < 3 or else Files.File_System.Supports_Ownership then
               Reset_Root;
               Write_Binary_File (Source, "owned bytes");
               Mutation := Files.File_System.Set_Permissions (Source, 8#644#);
               Assert (Mutation.Success, "prepare metadata source");
               Load := Files.File_System.Load_Directory (Root, Settings);
               Files.Model.Initialize (Model, Root, Load.Items, Root);
               Files.Model.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, Background);
               Select_Name (Model, "metadata-source");
               if Kind < 3 then
                  Step := Files.Operations.Set_Permissions_For (Model, (if Kind = 1 then 0 else 8#600#), Settings);
               else
                  Files.File_System.Ownership_Of (Source, Uid, Gid, Available);
                  Assert (Available, "read the current owner");
                  Step := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
               end if;
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "the live metadata change succeeds");
               Replace_And_Refuse (False);
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Success
                       and then Metadata_Mode_Of (Source) = 8#644#,
                       "metadata Undo can retry the restored inode, even from mode 000");
               Replace_And_Refuse (True);
               Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
               Await_View (Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "metadata Redo can retry the restored inode");
            end if;
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Metadata_History_Identity;
