separate (Files_Suite.Recovery)
   procedure Test_Job_Request_Path_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;
      Assert
        (Files.Jobs.Refresh.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => False),
         "refresh requests accept real absolute roots and the synthetic Recent view: absolute root");
      Assert
        (Files.Jobs.Refresh.Testing.Request_Paths_Are_Valid
           ("", "", Recent => True),
         "refresh requests accept real absolute roots and the synthetic Recent view: Recent view");
      Assert
        (not Files.Jobs.Refresh.Testing.Request_Paths_Are_Valid
           ("relative-root", Root, Recent => False),
         "refresh requests reject relative or contradictory path state: relative root");
      Assert
        (not Files.Jobs.Refresh.Testing.Request_Paths_Are_Valid
           (Root, "relative-signature", Recent => False),
         "refresh requests reject relative or contradictory path state: relative signature");
      Assert
        (not Files.Jobs.Refresh.Testing.Request_Paths_Are_Valid
           (Root, Root, Recent => True),
         "refresh requests reject relative or contradictory path state: Recent view with a root");
      Assert
        (Files.Jobs.Operation.Testing.Request_Path_Is_Valid
           (Root, Recent => False),
         "operation requests distinguish real roots from the synthetic Recent view: absolute root");
      Assert
        (Files.Jobs.Operation.Testing.Request_Path_Is_Valid
           ("", Recent => True),
         "operation requests distinguish real roots from the synthetic Recent view: Recent view");
      Assert
        (not Files.Jobs.Operation.Testing.Request_Path_Is_Valid
           ("relative-root", Recent => False),
         "operation requests distinguish real roots from the synthetic Recent view: relative root");
      Assert
        (not Files.Jobs.Operation.Testing.Request_Path_Is_Valid
           (Root, Recent => True),
         "operation requests distinguish real roots from the synthetic Recent view: Recent view with a root");
      Assert
        (Files.Jobs.Refresh.Testing.Watch_Request_Path_Is_Valid (Root),
         "watch requests require absolute NUL-free paths: absolute path");
      Assert
        (not Files.Jobs.Refresh.Testing.Watch_Request_Path_Is_Valid
           ("relative-watch"),
         "watch requests require absolute NUL-free paths: relative path");
      Assert
        (not Files.Jobs.Refresh.Testing.Watch_Request_Path_Is_Valid
           (Root & Character'Val (0) & "ignored"),
         "watch requests require absolute NUL-free paths: NUL in path");
   end Test_Job_Request_Path_Validation;
