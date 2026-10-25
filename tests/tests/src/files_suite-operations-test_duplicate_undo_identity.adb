separate (Files_Suite.Operations)
   procedure Test_Duplicate_Undo_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Source : constant String := Join (Root, "original");
      Dest : constant String := Join (Root, "original (copy)");
      Old_Dest : constant String := Join (Root, "old-copy");
      Target : constant String := Join (Root, "target");
      Old_Token : Unbounded_String;
   begin
      for Background in Boolean loop
         for Kind in 1 .. 3 loop
            Reset_Root;
            Write_Binary_File (Target, "target bytes");
            case Kind is
               when 1 => Write_Binary_File (Source, "same bytes");
               when 2 =>
                  Ada.Directories.Create_Directory (Source);
                  Write_Binary_File (Join (Source, "child"), "same bytes");
                  GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                    (Source, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
               when others =>
                  if not Hostkit.Fs.Create_Link (Target, Source) then
                     return;
                  end if;
            end case;
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Clear_Undo (Model);
            Files.Model.Set_Background_Transfers (Model, Background);
            Select_Name (Model, "original");
            Step := Complete_Operation (Model, Settings, Files.Operations.Duplicate_Selected (Model, Settings));
            Await_View (Model, Settings);
            Old_Token := To_Unbounded_String (Files.File_Identities.Token (Dest));
            Assert (Length (Old_Token) > 0, "record a non-following entry identity");
            if Kind = 2 then
               Write_Binary_File (Join (Dest, "user-added"), "new user bytes");
               Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
               Await_View (Model, Settings);
               Assert (Step.Status = Files.Operations.Operation_Failed
                       and then Files.Model.Undo_Available (Model)
                       and then File_Has_Bytes (Join (Dest, "child"), "same bytes")
                       and then File_Has_Bytes (Join (Dest, "user-added"), "new user bytes"),
                       "Undo refuses a copied directory after a user adds a child and retains the complete tree");
               Ada.Directories.Delete_File (Join (Dest, "user-added"));
               GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
                 (Dest, GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 8));
            end if;
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success
                    and then not (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo removes the entry it created");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Redo republishes the entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Success,
               "Undo uses the new identity recorded by Redo");
            Step := Complete_Operation (Model, Settings, Files.Operations.Redo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Hostkit.Fs.Move_No_Replace (Dest, Old_Dest), "retain the original inode at another path");
            Mutation := Files.File_System.Copy_Tree (Source, Dest);
            Assert (Mutation.Success, "replace the pathname with an identical but unrelated entry");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Failed
                    and then Files.Model.Undo_Available (Model)
                    and then (Ada.Directories.Exists (Dest) or else Hostkit.Fs.Is_Link (Dest)),
                    "Undo refuses a replacement even when its contents and link target are identical");
            Mutation := Files.File_System.Delete_Permanently (Dest);
            Assert (Mutation.Success and then Hostkit.Fs.Move_No_Replace (Old_Dest, Dest),
                    "put the owned entry back so the action can be retried");
            Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
            Await_View (Model, Settings);
            Assert (Step.Status = Files.Operations.Operation_Success and then not Files.Model.Undo_Available (Model),
                    "a refused Undo remains retryable when its owned entry is restored");
         end loop;
      end loop;
   exception
      when others => Files.Model.Clear_Paste_Execution (Model); Files.Refresh_Jobs.Cancel (Model); raise;
   end Test_Duplicate_Undo_Identity;
