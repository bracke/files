separate (Files_Suite.Operations)
   procedure Test_Replace_Trash_Failure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "replacement-source");
      Dest     : constant String := Join (Root, "replacement-original");
      Blocker  : constant String := Join (Root, "trash-blocker");
      Had_Xdg  : constant Boolean := Ada.Environment_Variables.Exists ("XDG_DATA_HOME");
      Had_Back : constant Boolean := Ada.Environment_Variables.Exists ("FILES_TRASH_BACKEND");
      Old_Xdg  : constant String :=
        (if Had_Xdg then
           Ada.Environment_Variables.Value ("XDG_DATA_HOME") else "");
      Old_Back : constant String :=
        (if Had_Back then
           Ada.Environment_Variables.Value ("FILES_TRASH_BACKEND") else "");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Step     : Files.Operations.Operation_Result;
      Backup   : Files.Types.UString;
      Mutation : Files.File_System.Mutation_Result;

      procedure Restore_Environment is
      begin
         if Had_Xdg then
            Ada.Environment_Variables.Set ("XDG_DATA_HOME", Old_Xdg);
         else
            Ada.Environment_Variables.Clear ("XDG_DATA_HOME");
         end if;
         if Had_Back then
            Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", Old_Back);
         else
            Ada.Environment_Variables.Clear ("FILES_TRASH_BACKEND");
         end if;
      end Restore_Environment;
   begin
      Reset_Root;
      Write_Binary_File (Source, "new");
      Write_Binary_File (Dest, "original");
      Write_Binary_File (Blocker, "not a directory");
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
         Assert (Step.Status = Files.Operations.Operation_Failed, "a trash failure aborts Replace");
         Assert (Project_Tools.Files.Read_Raw_File (Dest) = "original", "Replace keeps the original on trash failure");
      end loop;
      Restore_Environment;

      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Mutation := Files.File_System.Preserve_For_Replace (Dest, Backup);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Files.File_Identities.Testing.Set_Unavailable (False);
      Assert
        (not Mutation.Success
         and then Length (Backup) = 0
         and then File_Has_Bytes (Dest, "original"),
         "Replace refuses an unidentifiable original before moving it");
   exception
      when others =>
         Files.File_Identities.Testing.Set_Unavailable (False);
         Files.Model.Clear_Paste_Execution (Model);
         Restore_Environment;
         raise;
   end Test_Replace_Trash_Failure;
