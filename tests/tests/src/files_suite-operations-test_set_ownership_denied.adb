separate (Files_Suite.Operations)
   procedure Test_Set_Ownership_Denied (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "denied.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         Files_Suite.Support.Skip ("Test_Set_Ownership_Denied", "not Files.File_System.Supports_Ownership");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "deny me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "denied.txt");

      --  Attempt to give the file to root. A non-root process is refused with
      --  error.ownership.denied; a root test process would instead succeed.
      --  Either way there must be no crash.
      Result := Files.Operations.Set_Ownership_For (Model, 0, 0, Settings);
      if Result.Status = Files.Operations.Operation_Success then
         Assert (Uid = 0, "unexpected chown-to-root success only permitted when running as root");
      else
         Assert
           (Result.Status = Files.Operations.Operation_Failed,
            "chown to a different owner reports a failure");
         Assert
           (To_String (Result.Error_Key) = "error.ownership.denied",
            "chown denial surfaces error.ownership.denied");
         declare
            Now_Uid, Now_Gid : Natural := 0;
            Now_Avail        : Boolean := False;
         begin
            Files.File_System.Ownership_Of (Target, Now_Uid, Now_Gid, Now_Avail);
            Assert
              (Now_Avail and then Now_Uid = Uid and then Now_Gid = Gid,
               "a denied chown leaves the file ownership unchanged");
         end;
      end if;
   end Test_Set_Ownership_Denied;
