separate (Files_Suite.Operations)
   procedure Test_Permission_String_Agrees_With_The_Host (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings   : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Plain      : constant String := Join (Root, "plain-file.txt");
      Runnable   : constant String := Join (Root, "runnable.sh");
      Sub_Dir    : constant String := Join (Root, "a-directory");

      function Execute_Bit (Path : String) return Character is
         Loaded : constant Files.File_System.Item_Load_Result :=
           Files.File_System.Load_Item (Path, Settings);
         Text   : constant String := To_String (Loaded.Item.Permissions);
      begin
         Assert (Loaded.Success, "the item loads: " & Path);
         Assert (Text'Length = 3, "the permission column has three positions: " & Text);
         return Text (Text'First + 2);
      end Execute_Bit;
   begin
      Reset_Root;
      Write_File (Plain, "not runnable");
      Write_File (Runnable, "#!/bin/sh" & ASCII.LF & "exit 0");
      Ada.Directories.Create_Directory (Sub_Dir);

      --  Whatever the host says about each path is what the column must show.
      Assert
        (Execute_Bit (Plain) = (if Hostkit.Fs.Is_Executable (Plain) then 'x' else '-'),
         "a plain file's execute bit matches the host");
      Assert
        (Execute_Bit (Sub_Dir) = (if Hostkit.Fs.Is_Executable (Sub_Dir) then 'x' else '-'),
         "a directory's execute bit matches the host");

      if Files.File_System.Set_Permissions (Runnable, 8#755#).Success then
         Assert
           (Execute_Bit (Runnable) = (if Hostkit.Fs.Is_Executable (Runnable) then 'x' else '-'),
            "a file the host will run matches the host");

         --  Set_Permissions succeeding is not the same as this host deciding
         --  executability by mode: on Windows it writes an ACL and succeeds,
         --  while what may be run is decided by the extension, so a chmod +x
         --  .sh file is correctly not executable there. Mode_Bits_Are_Native is
         --  the question that was meant, and asking the other one asserted POSIX
         --  of a host that never claimed it.
         if Hostkit.Metadata.Mode_Bits_Are_Native then
            Assert
              (Execute_Bit (Runnable) = 'x',
               "and where mode decides it, chmod +x really does show as executable");
         end if;
      end if;

      --  The read and write positions, across the mode matrix, against the same
      --  host calls the column is built from. This is what says whether those
      --  two answers may be taken from mode bits already read for the item
      --  instead of asked for separately: if the two ever disagreed, the column
      --  would go quietly wrong rather than fail.
      declare
         Probe : constant String := Join (Root, "rw-probe.txt");

         procedure Check_At (Mode : Natural) is
            Applied : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Probe, Mode);
         begin
            if not Applied.Success then
               return;
            end if;

            declare
               Loaded : constant Files.File_System.Item_Load_Result :=
                 Files.File_System.Load_Item (Probe, Settings);
               Text   : constant String := To_String (Loaded.Item.Permissions);
               Label  : constant String := Natural'Image (Mode);
            begin
               Assert (Loaded.Success and then Text'Length = 3, "the probe loads at mode" & Label);
               Assert
                 (Text (Text'First) = (if GNAT.OS_Lib.Is_Owner_Readable_File (Probe) then 'r' else '-'),
                  "the read position matches the host at mode" & Label);
               Assert
                 (Text (Text'First + 1) = (if GNAT.OS_Lib.Is_Owner_Writable_File (Probe) then 'w' else '-'),
                  "the write position matches the host at mode" & Label);
            end;
         end Check_At;
      begin
         Write_File (Probe, "probe");
         Check_At (8#644#);
         Check_At (8#600#);
         Check_At (8#400#);
         Check_At (8#200#);
         Check_At (8#444#);
         Check_At (8#000#);

         --  Leave it removable for Reset_Root.
         declare
            Restored : constant Files.File_System.Mutation_Result :=
              Files.File_System.Set_Permissions (Probe, 8#644#);
            pragma Unreferenced (Restored);
         begin
            null;
         end;
      end;
   end Test_Permission_String_Agrees_With_The_Host;
