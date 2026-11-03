with Files.Process_Jobs.Testing;
separate (Files_Suite.Operations)
   --  A background paste whose helper cannot start (a process limit, a full
   --  temporary volume) ends with an error. It used to raise from every loop
   --  pass instead, leaving the paste armed and the window unpainted.
   procedure Test_Paste_Helper_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "refused-source");
      Dest_Dir : constant String := Join (Root, "refused-dest");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dest_Dir);
      Write_Binary_File (Source, "refused");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (Dest_Dir, "refused-source")), False, False));
      Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Operations.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy);
      Files.Process_Jobs.Testing.Refuse_Next_Launch;
      Step := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
      Assert (not Files.Model.Paste_Execution_Is_Active (Model), "the paste ends instead of staying armed");
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Failed, "and reports the failure");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.drop.failed", "with an error the window shows");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "refused-source")), "nothing was written");
   end Test_Paste_Helper_Refused;
