separate (Files_Suite.Operations)
   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "replacement-source");
      Dest     : constant String := Join (Root, "replacement-original");
      Blocker  : constant String := Join (Root, "trash-blocker");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Backup   : Files.Types.UString;
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_Binary_File (Source, "new");
      Write_Binary_File (Dest, "original");
      Write_Binary_File (Blocker, "not a directory");
      declare
         --  The trash sandbox ends with this block: the identity check below runs in the real environment.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Environment, "XDG_DATA_HOME");
         Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Blocker);
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
         Actions.Append (Files.Paste.Resolved_Action'
                           (To_Unbounded_String (Source), To_Unbounded_String (Dest), False, True));
         for Background in Boolean loop
            Load := Files.File_System.Load_Directory (Root, Settings);
            Files.Model.Initialize (Model, Root, Load.Items, Root);
            Files.Model.Set_Background_Transfers (Model, Background);
            Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
            for Attempt in Files_Suite.Support.Polling loop
               Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               exit when not Files.Model.Paste_Execution_Is_Active (Model);
            end loop;
            Assert (not Files.Model.Paste_Execution_Is_Active (Model), "a failed Replace finishes its execution");
            Files_Suite.Support.Assert_Equal
              (Step.Status,
               Files.Operations.Operation_Failed,
               "a trash failure aborts Replace");
            Files_Suite.Support.Assert_Equal
              (Project_Tools.Files.Read_Raw_File (Dest),
               "original",
               "Replace keeps the original on trash failure");
         end loop;
      end;

      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Mutation := Files.File_System.Preserve_For_Replace (Dest, Backup);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Files.File_Identities.Testing.Set_Unavailable (False);
      Assert (not Mutation.Success, "Replace refuses an unidentifiable original before moving it: refused");
      Files_Suite.Support.Assert_Equal
        (Length (Backup),
         0,
         "Replace refuses an unidentifiable original before moving it: no backup");
      Assert
        (File_Has_Bytes (Dest, "original"),
         "Replace refuses an unidentifiable original before moving it: original kept");
   exception
      when others =>
         Files.File_Identities.Testing.Set_Unavailable (False);
         Files.Model.Clear_Paste_Execution (Model);
         raise;
   end Test_Replace_Trash_Failure;
