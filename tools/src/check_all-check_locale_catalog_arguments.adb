separate (Check_All)
   procedure Check_Locale_Catalog_Arguments is
      --  The default catalog, and every locale's {arguments} against it, by
      --  the messages crate's catalog checker, from the sibling checkout the
      --  build pins (alire.toml: messages = { path = "../messages" }).
      Tool_Dir : constant String := Root & "/../messages/tools/catalog_check";
      Tool     : constant String := Tool_Dir & "/bin/catalog_check";
      Base     : constant String := Root & "/share/files.catalog";
      Output   : Unbounded_String;
      Checked  : Natural := 0;
   begin
      Run ("catalog_check build", Tool_Dir, Alr, [new String'("--non-interactive"), new String'("build")]);
      --  The default catalog itself: well-formed, and an option name it holds
      --  verbatim for the program "files" is not translated away.
      if Project_Tools.Processes.Run_Status
           (Label   => "catalog_check files.catalog",
            Dir     => Tool_Dir,
            Program => Tool,
            Args    =>
              GNAT.OS_Lib.Argument_List'[new String'(Base), new String'("--verbatim=files")],
            Output  => Output,
            Quiet   => True) /= 0
      then
         Report (Base & ": the message catalogue check failed (findings above) " & To_String (Output));
      end if;
      for Locale of Project_Tools.Files.List_Tree (Root & "/share/locales", "files-*.catalog", Generated_Directories)
      loop
         Checked := Checked + 1;
         --  Its findings go to standard error; the summary it prints on
         --  standard output is kept in Output, and shown only on a failure.
         if Project_Tools.Processes.Run_Status
              (Label   => "catalog_check " & Ada.Directories.Simple_Name (To_String (Locale)),
               Dir     => Tool_Dir,
               Program => Tool,
               Args    =>
                 GNAT.OS_Lib.Argument_List'
                   [new String'(To_String (Locale)),
                    new String'("--base=" & Base),
                    new String'("--arguments-only")],
               Output  => Output,
               Quiet   => True) /= 0
         then
            --  One problem per catalog that disagrees.
            Report
              (To_String (Locale) & ": its {arguments} differ from share/files.catalog's (findings above) "
               & To_String (Output));
         end if;
      end loop;
      if Checked = 0 then
         Report ("no locale catalog under share/locales to check against share/files.catalog");
      end if;
   end Check_Locale_Catalog_Arguments;
