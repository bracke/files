separate (Files_Suite.Operations)
   procedure Test_Reserve_Exception_Safety (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Invalid_Temp : constant String := Join (Root, "not-a-temp-directory");
      Job          : Files.Process_Jobs.Session;
      Failed       : Boolean := False;
      type Name_Access is access constant String;
      Tmpdir : aliased constant String := "TMPDIR";
      Tmp    : aliased constant String := "TMP";
      Temp   : aliased constant String := "TEMP";
      Temp_Variables : constant array (1 .. 3) of Name_Access :=
        [Tmpdir'Access, Tmp'Access, Temp'Access];
   begin
      Reset_Root;
      Write_Binary_File (Invalid_Temp, "ordinary file");
      declare
         --  The temporary directory's variables come back when this block
         --  ends, on failure too. POSIX reads TMPDIR; Windows' GetTempPathW
         --  reads TMP, then TEMP.
         Environment : Files_Suite.Support.Environment_Guard;
      begin
         for Name of Temp_Variables loop
            Files_Suite.Support.Save (Environment, Name.all);
            Ada.Environment_Variables.Set (Name.all, Invalid_Temp);
         end loop;
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
