with Files.Model.Jobs;
with Files.Operations.Paste.Testing;
with Files.Operations.Paste;
with Files.File_System_Types;
with Files_Suite.Listings;
with Files.Operation_Results;
with Files.Job_Drivers.Foreground;
with Files.Jobs.Process.Testing;
with Files_Suite.Support.Guards;
separate (Files_Suite.Transfer)
   --  A background paste whose helper cannot start (a process limit, a full
   --  temporary volume) ends with an error. It used to raise from every loop
   --  pass instead, leaving the paste armed and the window unpainted.
   procedure Test_Paste_Helper_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Source   : constant String := Join (Root, "refused-source");
      Dest_Dir : constant String := Join (Root, "refused-dest");
      Actions  : Files.Paste.Resolved_Action_Vectors.Vector;
      Model    : aliased Files.Model.Window_Model;
      Paste    : Files_Suite.Support.Guards.Paste_Guard (Model'Access);
      pragma Unreferenced (Paste);
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dest_Dir);
      Write_Binary_File (Source, "refused");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (To_Unbounded_String (Source), To_Unbounded_String (Join (Dest_Dir, "refused-source")), False, False));
      Load := Files_Suite.Listings.Load_Directory (Dest_Dir, Settings);
      Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Files.Operations.Paste.Testing.Begin_Paste_Execution (Model, Actions, Files.File_System_Types.Drop_Copy);
      Files.Jobs.Process.Testing.Refuse_Next_Launch;
      Step := Files.Job_Drivers.Foreground.Advance (Model, Settings, 1);
      Files.Jobs.Process.Testing.Clear_Refusal;
      Assert (not Files.Model.Jobs.Foreground_Job_Is_Active (Model), "the paste ends instead of staying armed");
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Failed, "and reports the failure");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.drop.failed", "with an error the window shows");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "refused-source")), "nothing was written");
   exception
      when others =>
         Files.Jobs.Process.Testing.Clear_Refusal;
         raise;
   end Test_Paste_Helper_Refused;
