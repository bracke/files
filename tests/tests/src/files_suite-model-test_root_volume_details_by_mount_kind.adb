separate (Files_Suite.Model)
   procedure Test_Root_Volume_Details_By_Mount_Kind (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Snapshot : Files.Rendering.View_Snapshot;
   begin
      declare
         Bad_Root : constant Files.File_System.Root_Entry :=
           (Path        => To_Unbounded_String (Root & "/bad" & Character'Val (0) & "root"),
            Label       => To_Unbounded_String ("bad"),
            Kind        => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("bad"),
            Ready       => Files.File_System.Root_Inaccessible,
            Removable   => False);
         Bad_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Bad_Root);
      begin
         Files_Suite.Support.Assert_Equal
           (To_String (Bad_Detail.Native_Api_Name),
            "none",
            "malformed root volume detail skips platform adapter");
         Assert
           (not Bad_Detail.Uses_Platform_Detail,
            "malformed root volume detail has no platform metadata");
      end;
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => To_Unbounded_String ("/run/user/1000/gvfs/smb-share:server=nas,share=docs"),
            Label => To_Unbounded_String ("root.network_mount|nas-docs|cifs"),
            Kind  => Files.File_System.Root_Network_Mount,
            Volume_Name => To_Unbounded_String ("nas-docs"),
            Ready => Files.File_System.Root_Ready,
            Removable => False));
      declare
         Network_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Entries.Element (1));
      begin
         Assert (Network_Detail.Network_Mount, "network root detail marks remote mounts");
         Files_Suite.Support.Assert_Equal
           (To_String (Network_Detail.Remote_Protocol),
            "smb",
            "network root detail derives SMB protocol from GVFS path");
         Assert (Network_Detail.Offline_Possible, "network root detail marks offline risk");
         Assert (Network_Detail.Auth_May_Be_Required, "network root detail marks authentication risk");
         Assert (Network_Detail.Latency_Sensitive, "network root detail marks latency risk");
         Assert
           (Network_Detail.Special_Error_Recovery,
            "network root detail marks special recovery policy");
      end;
      Files.Model.Open_Root_Selector (Model, Entries);
      Snapshot := Files.Rendering.Build_Snapshot (Model);
      Assert
        (To_String (Snapshot.Root_Labels.Element (1)) =
         Files.Localization.Text ("root.network_mount.prefix") & "nas-docs" &
         Files.Localization.Text ("root.detail.prefix") & "cifs" &
         Files.Localization.Text ("root.detail.suffix") &
         Files.Localization.Text ("root.network_mount.suffix"),
         "root selector renders localized network root labels");
      Entries.Clear;
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path        => To_Unbounded_String ("/tmp/local-root"),
            Label       => To_Unbounded_String ("root.mount|local-root|ext4"),
            Kind        => Files.File_System.Root_Mount,
            Volume_Name => To_Unbounded_String ("local-root"),
            Ready       => Files.File_System.Root_Ready,
            Removable   => False));
      declare
         Local_Detail : constant Files.File_System.Root_Volume_Details :=
           Files.File_System.Root_Volume_Details_For (Entries.Element (1));
      begin
         Assert (not Local_Detail.Network_Mount, "local root detail does not claim network status");
         Files_Suite.Support.Assert_Equal
           (To_String (Local_Detail.Remote_Protocol),
            "",
            "local root detail has no remote protocol");
         Assert (not Local_Detail.Offline_Possible, "local root detail has no offline network risk");
         Assert
           (not Local_Detail.Auth_May_Be_Required,
            "local root detail has no network authentication risk");
         Assert (not Local_Detail.Latency_Sensitive, "local root detail has no network latency risk");
         Assert
           (not Local_Detail.Special_Error_Recovery,
            "local root detail has no network recovery policy");
      end;
   end Test_Root_Volume_Details_By_Mount_Kind;
