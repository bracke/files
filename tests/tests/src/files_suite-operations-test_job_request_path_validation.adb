separate (Files_Suite.Operations)
   procedure Test_Job_Request_Path_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;
      Assert
        (Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => False)
         and then Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           ("", "", Recent => True),
         "refresh requests accept real absolute roots and the synthetic Recent view");
      Assert
        (not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           ("relative-root", Root, Recent => False)
         and then not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, "relative-signature", Recent => False)
         and then not Files.Refresh_Jobs.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => True),
         "refresh requests reject relative or contradictory path state");
      Assert
        (Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           (Root, Recent => False)
         and then Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           ("", Recent => True)
         and then not Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           ("relative-root", Recent => False)
         and then not Files.Operation_Jobs.Testing.Request_Path_Is_Valid
           (Root, Recent => True),
         "operation requests distinguish real roots from the synthetic Recent view");
      Assert
        (Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid (Root)
         and then not Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid
           ("relative-watch")
         and then not Files.Refresh_Jobs.Testing.Watch_Request_Path_Is_Valid
           (Root & Character'Val (0) & "ignored"),
         "watch requests require absolute NUL-free paths");
   end Test_Job_Request_Path_Validation;
