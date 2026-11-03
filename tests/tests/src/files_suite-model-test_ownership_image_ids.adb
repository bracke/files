separate (Files_Suite.Model)
   procedure Test_Ownership_Image_Ids (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Valid (Text : String) return Boolean is
        (Files.Model.Valid_Ownership_Image (Ada.Strings.Unbounded.To_Unbounded_String (Text)));
      Nul : constant Character := ASCII.NUL;
   begin
      Assert (Valid ("1000 1000"), "an ordinary uid and gid are a payload");
      --  NFS's nobody and an idmapped mount's ids are past Natural'Last; the
      --  chown succeeded, so its undo must not be dropped.
      Assert (Valid ("4294967294 4294967294"), "ids past Natural'Last are a payload too");
      Assert (Valid ("4294967295 0" & Nul & "nobody" & Nul & "root"), "with names after the ids");
      Assert (not Valid ("4294967296 0"), "a value past 32 bits is not an id");
      Assert (not Valid ("-1 0"), "nor is a negative one");
      Assert (not Valid ("16#FF# 0"), "nor Ada literal syntax");
      Assert (not Valid ("1000"), "both ids are needed");
   end Test_Ownership_Image_Ids;
