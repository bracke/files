separate (Files_Suite.Operations)
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      Invalid_Temp : constant String := Join (Root, "not-a-temp-directory");
      Job          : Files.Process_Jobs.Session;
      Failed       : Boolean := False;

      procedure Restore_Temp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Temp;
   begin
      if Hostkit.Host.Current not in Hostkit.Host.Linux | Hostkit.Host.MacOS then
         Files_Suite.Support.Skip
           ("Test_Reserve_Exception_Safety",
            "Hostkit.Host.Current not in Hostkit.Host.Linux | Hostkit.Host.MacOS");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Invalid_Temp, "ordinary file");
      Ada.Environment_Variables.Set ("TMPDIR", Invalid_Temp);
      begin
         Files.Process_Jobs.Reserve (Job);
      exception
         when others => Failed := True;
      end;
      Assert
        (Failed and then not Files.Process_Jobs.Active (Job),
         "a transport creation failure frees the preallocated session state");

      Restore_Temp;
      Files.Process_Jobs.Reserve (Job);
      Assert
        (Files.Process_Jobs.Active (Job)
         and then Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "")),
         "the same session remains reusable after reservation rollback");
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Restore_Temp;
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Reserve_Exception_Safety;
