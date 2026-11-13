separate (Check_All)
   procedure Check_Packaging_Metadata is
      Stage : constant String := Temp_Path ("install-stage");

      procedure Require_Manifest_Entry
        (Path    : String;
         Message : String) is separate;

      procedure Require_Share_Files_In_Manifest (Path : String) is separate;

      procedure Check_Manifest_Entries is separate;

      procedure Copy_Share_Tree
        (From_Path : String;
         To_Path   : String)
      is separate;

      procedure Check_Staged_Manifest_Entries is separate;

      --  The packaging metadata in the source tree: required files, the
      --  desktop entry, the AppStream metadata and the package manifest.
      procedure Check_Source_Metadata is separate;

      --  The share tree staged as an install lays it out, and the metadata
      --  that must survive the staging; the stage is removed at the end.
      procedure Check_Staged_Metadata is separate;
   begin
      Check_Source_Metadata;
      Require_Share_Files_In_Manifest (Root & "/share");
      Check_Manifest_Entries;
      Check_Staged_Metadata;
   end Check_Packaging_Metadata;
