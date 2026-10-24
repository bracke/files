separate (Files_Suite.Operations)
   procedure Test_Set_Ownership_Identity_And_Undo (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target   : constant String := Join (Root, "ownable.txt");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Operations.Operation_Result;
      Uid, Gid : Natural := 0;
      Avail    : Boolean := False;
   begin
      if not Files.File_System.Supports_Ownership then
         Files_Suite.Support.Skip ("Test_Set_Ownership_Identity_And_Undo", "not Files.File_System.Supports_Ownership");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "own me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "ownable.txt");

      --  Setting ownership to the file's OWN uid/gid is permitted even for a
      --  non-root process, so this exercises the primitive and undo plumbing.
      Result := Files.Operations.Set_Ownership_For (Model, Uid, Gid, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Success,
         "identity chown to the file's own owner succeeds");
      Assert
        (Files.Model.Undo_Kind_Of (Model) = Files.Model.Undo_Set_Ownership,
         "set-ownership records an ownership undo");

      declare
         Payload : constant String :=
           To_String
             (Files.Model.Undo_History (Model).Last_Element.To.First_Element);
         First_Separator : constant Natural :=
           Ada.Strings.Fixed.Index
             (Payload, String'(1 => Ada.Characters.Latin_1.NUL));
         Second_Separator : constant Natural :=
           (if First_Separator = 0
            then 0
            else Ada.Strings.Fixed.Index
              (Payload,
               String'(1 => Ada.Characters.Latin_1.NUL),
               From => First_Separator + 1));
      begin
         Assert
           (First_Separator > 0 and then Second_Separator > First_Separator,
            "ownership history retains names for a later helper process");
      end;

      Result := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
      Assert (Result.Status = Files.Operations.Operation_Success, "undo of chown succeeds");
      Assert (not Files.Model.Undo_Available (Model), "undo record is cleared after chown undo");

      declare
         New_Uid, New_Gid : Natural := 0;
         Now_Avail        : Boolean := False;
      begin
         Files.File_System.Ownership_Of (Target, New_Uid, New_Gid, Now_Avail);
         Assert
           (Now_Avail and then New_Uid = Uid and then New_Gid = Gid,
            "ownership is unchanged after identity chown and undo");
      end;
   end Test_Set_Ownership_Identity_And_Undo;
