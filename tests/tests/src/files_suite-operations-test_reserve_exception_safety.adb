separate (Files_Suite.Operations)
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Invalid_Temp : constant String := Join (Root, "not-a-temp-directory");
      Job          : Files.Process_Jobs.Session;
      Failed       : Boolean := False;
   begin
      if Hostkit.Host.Current not in Hostkit.Host.Linux | Hostkit.Host.MacOS then
         Files_Suite.Support.Skip
           ("Test_Reserve_Exception_Safety",
            "needs Linux or macOS");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Invalid_Temp, "ordinary file");
      declare
         --  TMPDIR comes back when this block ends, on failure too.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         Files_Suite.Support.Save (Environment, "TMPDIR");
         Ada.Environment_Variables.Set ("TMPDIR", Invalid_Temp);
         begin
            Files.Process_Jobs.Reserve (Job);
         exception
            when others => Failed := True;
         end;
         Assert (Failed, "a transport creation failure frees the preallocated session state: reservation fails");
         Assert
           (not Files.Process_Jobs.Active (Job),
            "a transport creation failure frees the preallocated session state: session inactive");
      end;

      Files.Process_Jobs.Reserve (Job);
      Assert
        (Files.Process_Jobs.Active (Job)
         and then Ada.Directories.Exists (Files.Process_Jobs.Path (Job, "")),
         "the same session remains reusable after reservation rollback");
      Files.Process_Jobs.Reset (Job);
   exception
      when others =>
         Files.Process_Jobs.Reset (Job);
         raise;
   end Test_Reserve_Exception_Safety;
