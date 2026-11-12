with Files.Fs_Primitives;
separate (Files_Suite.Operations)
   procedure Test_Staging_Default_ACL (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Set_Default_ACL (Path : System.Address; Owner : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_default_acl";
      function Add_Inherited_Ace (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_add_inherited_ace";
      function Inherits_Ace (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_inherits_ace";
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source : constant String := Join (Root, "source");
      Parent : constant String := Join (Root, "destination");
      Dest : constant String := Join (Parent, "copy");
      Model : Files.Model.Window_Model;
      Load : Files.File_System.Directory_Load_Result;
      Step : Files.Operations.Operation_Result;
      Mutation : Files.File_System.Mutation_Result;
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;

      --  What needs no ACL fixture, checked on every other host: a job
      --  transport and a private stage made in the temporary directory the
      --  environment names -- TMPDIR on POSIX, TMP and then TEMP for
      --  Windows' GetTempPathW -- are their owner's alone, usable and
      --  cleaned up, and a copy into that folder still works.
      procedure Check_Private_Temp is
         type Name_Access is access constant String;
         Tmpdir : aliased constant String := "TMPDIR";
         Tmp    : aliased constant String := "TMP";
         Temp   : aliased constant String := "TEMP";
         Temp_Variables : constant array (1 .. 3) of Name_Access := [Tmpdir'Access, Tmp'Access, Temp'Access];
         Job         : Files.Process_Jobs.Session;
         Transport   : Files.Types.UString;
         Stage       : Unbounded_String;
         --  The variables come back when this ends, on failure too.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         Reset_Root;
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Source, "copied bytes");
         for Name of Temp_Variables loop
            Files_Suite.Support.Save (Environment, Name.all);
            Ada.Environment_Variables.Set (Name.all, Parent);
         end loop;
         Files.Process_Jobs.Reserve (Job);
         Transport := To_Unbounded_String (Files.Process_Jobs.Path (Job, ""));
         Assert
           (Hostkit.Metadata.Same_File (Files.Fs_Primitives.Parent_Directory (To_String (Transport)), Parent),
            "the job transport is made in the temporary directory the environment names");
         Assert (Is_Owner_Only (To_String (Transport)), "the job transport is owner-only from creation");
         Write_Binary_File (Files.Process_Jobs.Path (Job, "request"), "private request");
         Assert
           (File_Has_Bytes (Files.Process_Jobs.Path (Job, "request"), "private request"),
            "the private transport's payload is usable");
         Files.Process_Jobs.Reset (Job);
         Assert (not Ada.Directories.Exists (To_String (Transport)), "the private transport is cleaned up");
         Stage := To_Unbounded_String (Files.Job_Context.Create_Stage (Parent));
         Assert (Is_Owner_Only (To_String (Stage)), "private staging is owner-only");
         --  Through Job_Context, which then lets its foreground job go: a
         --  stage deleted behind its back leaves that job's lease held open in
         --  the folder TMP names, and Windows cannot delete an open file.
         Assert (Files.Job_Context.Discard_Stage (To_String (Stage)), "remove the private staging probe");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Assert
           (Mutation.Success and then File_Has_Bytes (Dest, "copied bytes") and then File_Is (Source, "copied bytes"),
            "copying into the temporary directory succeeds and keeps its source");
      exception
         when others =>
            Files.Process_Jobs.Reset (Job);
            raise;
      end Check_Private_Temp;

      --  Windows' counterpart of a default ACL: the destination folder hands
      --  down an extra ACE. A copy is made in an owner-only private stage and
      --  renamed into place, which on Windows keeps what the stage handed
      --  down; once published it must hold what its folder hands down
      --  instead -- and so must everything a copied folder holds -- with no
      --  OWNER RIGHTS ACE left from the stage. A folder's recorded revision
      --  must still be the one Undo finds.
      procedure Check_Inherited_Access is
         Folder : constant String := Join (Root, "folder");
         Paths  : Files.Types.String_Vectors.Vector;

         function Inherits (Path : String) return Boolean is
            Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
         begin
            return Inherits_Ace (Name'Address) = 1;
         end Inherits;

         procedure Cleanup is
         begin
            Files.Model.Clear_Paste_Execution (Model);
            Files.Refresh_Jobs.Cancel (Model);
         end Cleanup;
      begin
         Reset_Root;
         Ada.Directories.Create_Directory (Parent);
         Write_Binary_File (Source, "copied bytes");
         Ada.Directories.Create_Directory (Folder);
         Write_Binary_File (Join (Folder, "child"), "child bytes");
         declare
            Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Parent);
         begin
            Assert (Add_Inherited_Ace (Name'Address) = 1, "give the destination folder an extra inheritable ACE");
         end;
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         Assert (Mutation.Success and then File_Has_Bytes (Dest, "copied bytes"), "copy a file into that folder");
         Assert
           (Inherits (Dest),
            "the published copy holds the folder's ACE and no OWNER RIGHTS ACE from its stage"
            & (if Inherits (Dest) then "" else Files_Suite.Support.Access_Report (Dest)));
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Operations.Clear_Undo (Model);
         Files.Model.Set_Background_Transfers (Model, True);
         Paths.Append (To_Unbounded_String (Folder));
         Step := Complete_Operation
           (Model, Settings, Files.Operations.Begin_Paste_To (Model, Settings, Paths, Parent));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success, "copy a folder into it in the background");
         Assert
           (Inherits (Join (Parent, "folder")) and then Inherits (Join (Parent, "folder/child"))
              and then File_Has_Bytes (Join (Parent, "folder/child"), "child bytes"),
            "the copied folder and what it holds take the folder's ACE, not the stage's");
         Step := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Await_View (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status, Files.Operations.Operation_Success,
            "Undo the folder copy: its recorded revision is the one inheriting left");
         Assert (not Ada.Directories.Exists (Join (Parent, "folder")), "Undo removed the copied folder");
         Cleanup;
      exception
         when others =>
            Cleanup;
            raise;
      end Check_Inherited_Access;
   begin
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Check_Private_Temp;
         Check_Inherited_Access;
         return;
      elsif Hostkit.Host.Current /= Hostkit.Host.Linux then
         Check_Private_Temp;
         Files_Suite.Support.Skip
           ("Test_Staging_Default_ACL",
            "the default-ACL fixture is a Linux POSIX ACL");
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
               Assert (Files.Job_Context.Discard_Stage (To_String (Stage)), "remove the private staging probe");
            end;
            if Background then
               Load := Files.File_System.Load_Directory (Parent, Settings);
               Files.Model.Initialize (Model, Parent, Load.Items, Parent);
               Files.Operations.Clear_Undo (Model);
               Files.Model.Set_Background_Transfers (Model, True);
               Actions.Clear;
               Actions.Append (Files.Paste.Resolved_Action'
                 (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, False));
               Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, False);
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
            Assert (File_Has_Bytes (Dest, "copied bytes") and then File_Is (Source, "copied bytes"),
                    "copying succeeds without changing the source or the destination's ACL policy");
         end loop;
      end loop;
   end Test_Staging_Default_ACL;
