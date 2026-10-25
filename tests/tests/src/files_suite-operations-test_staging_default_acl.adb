separate (Files_Suite.Operations)
   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Set_Default_ACL (Path : System.Address; Owner : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_default_acl";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "copy");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Staging_Default_ACL", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      for Background in Boolean loop
         for Owner in 0 .. 1 loop
            Reset_Root;
            Ada.Directories.Create_Directory (Parent);
            Write_Binary_File (Source, "copied bytes");
            declare
               Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Parent);
               Stage : Unbounded_String;
            begin
               Assert (Set_Default_ACL (Name'Address, Interfaces.C.int (Owner * 4)) = 1,
                       "prepare owner-none or owner-read-only default ACL on a writable destination");
               declare
                  Job       : Files.Process_Jobs.Session;
                  Transport : Files.Types.UString;
                  --  TMPDIR comes back when this block ends, on failure too.
                  Environment : Files_Suite.Support.Environment_Guard;
               begin
                  Files_Suite.Support.Save (Environment, "TMPDIR");
                  Ada.Environment_Variables.Set ("TMPDIR", Parent);
                  begin
                     Files.Process_Jobs.Reserve (Job);
                     Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
                     Files_Suite.Support.Assert_Equal
                       (Metadata_Mode_Of (To_String (Transport)),
                        8#700#,
                        "job transport is owner-only from creation despite the inherited default ACL");
                     Write_Binary_File (Files.Process_Jobs.Path (Job, "request"), "private request");
                     Assert
                       (File_Has_Bytes (Files.Process_Jobs.Path (Job, "request"), "private request"),
                        "private transport payload remains usable after removing the inherited ACL");
                     Files.Process_Jobs.Reset (Job);
                     Assert
                       (not Ada.Directories.Exists (To_String (Transport)),
                        "private transport remains eligible for guarded cleanup");
                  exception
                     when others =>
                        Files.Process_Jobs.Reset (Job);
                        raise;
                  end;
               end;
               Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Parent));
               Files_Suite.Support.Assert_Equal
                 (Metadata_Mode_Of (To_String (Stage)),
                  8#700#,
                  "private staging restores owner access without granting peer access");
               Mutation := Files.File_System.Delete_Permanently (To_String (Stage));
               Assert (Mutation.Success, "remove the private staging probe");
            end;
            if Background then
               Load := Files.File_System.Load_Directory (Parent, Settings);
               Files.Model.Initialize (Model, Parent, Load.Items, Parent);
               Files.Operations.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, True);
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
               Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
               Step := Complete_Operation
                 (Model, Settings, Files.Operations.Advance_Paste_Execution (Model, Settings, 1));
               Await_View (Model, Settings);
               Files_Suite.Support.Assert_Equal
                 (Step.Status,
                  Files.Operations.Operation_Success,
                  "background copy through a restrictive default ACL");
            else
               Mutation := Files.File_System.Copy_Tree (Source, Dest);
               Assert (Mutation.Success, "foreground copy through a restrictive default ACL");
            end if;
            Assert (File_Has_Bytes (Dest, "copied bytes") and then File_Has_Bytes (Source, "copied bytes"),
                    "copying succeeds without changing the source or the destination's ACL policy");
         end loop;
      end loop;
   end Test_Staging_Default_ACL;
