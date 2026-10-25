separate (Files_Suite.Operations)
   procedure Test_Io_Error_Classifier (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Io_Errors;
      Fallback : constant String := "error.copy.failed";

      procedure Expect (Code : Integer; Key : String; Name : String) is
      begin
         Assert_Equal (Key_For_Errno (Code, Fallback), Key, Name & " names its cause");
      end Expect;
   begin
      Assert_Equal (Key_Of (No_Space), "error.io.no_space", "a full disk has its key");
      Assert_Equal (Key_Of (Quota_Exceeded), "error.io.no_space", "a full quota reads as no space");
      Assert_Equal (Key_Of (Permission_Denied), "error.io.denied", "a refusal has its key");
      Assert_Equal (Key_Of (Not_Permitted), "error.io.denied", "a missing privilege reads as denied");
      Assert_Equal (Key_Of (Read_Only_Filesystem), "error.io.read_only", "a read-only mount has its key");
      Assert_Equal (Key_Of (Busy), "error.io.busy", "a busy device has its key");
      Assert_Equal (Key_Of (Text_Busy), "error.io.busy", "a running program reads as busy");
      Assert_Equal (Key_Of (Name_Too_Long), "error.io.name_too_long", "a long name has its key");
      for Item in Cause loop
         if Host_Code (Item) /= 0 then
            Expect (Host_Code (Item), Key_Of (Item), Cause'Image (Item));
         end if;
         Assert (Is_Cause_Key (Key_Of (Item)), Cause'Image (Item) & " key is a cause key");
         Assert (Files.Localization.Text (Key_Of (Item)) /= Key_Of (Item), Key_Of (Item) & " is localized");
      end loop;
      case Hostkit.Host.Current is
         when Hostkit.Host.Linux =>
            Expect (28, "error.io.no_space", "ENOSPC");
            Expect (122, "error.io.no_space", "EDQUOT");
            Expect (13, "error.io.denied", "EACCES");
            Expect (1, "error.io.denied", "EPERM");
            Expect (30, "error.io.read_only", "EROFS");
            Expect (16, "error.io.busy", "EBUSY");
            Expect (26, "error.io.busy", "ETXTBSY");
            Expect (36, "error.io.name_too_long", "ENAMETOOLONG");
         when Hostkit.Host.MacOS =>
            Expect (69, "error.io.no_space", "EDQUOT");
            Expect (63, "error.io.name_too_long", "ENAMETOOLONG");
         when Hostkit.Host.Windows =>
            Expect (38, "error.io.name_too_long", "ENAMETOOLONG");
            Expect (139, "error.io.busy", "ETXTBSY");
         when Hostkit.Host.Unsupported =>
            null;
      end case;
      --  ENOENT and EEXIST are 2 and 17 on every host: causes the caller
      --  already tells apart, so they keep its key.
      Assert_Equal (Key_For_Errno (0, Fallback), Fallback, "no errno keeps the generic key");
      Assert_Equal (Key_For_Errno (2, Fallback), Fallback, "a missing entry keeps the generic key");
      Assert_Equal (Key_For_Errno (17, Fallback), Fallback, "an existing entry keeps the generic key");
      Assert_Equal (Key_For_Errno (-1, Fallback), Fallback, "an impossible errno keeps the generic key");
      Assert (not Is_Cause_Key (Fallback), "a generic key is not a cause key");

      Reset;
      Assert_Equal (Last_Code, 0, "Reset forgets the recorded code");
      Assert_Equal (Key_For_Last (Fallback), Fallback, "nothing recorded keeps the generic key");
      Record_Code (Host_Code (Permission_Denied));
      Record_Code (0);
      Assert_Equal (Key_For_Last (Fallback), "error.io.denied", "a zero code keeps the recorded cause");
      Record_Code (Host_Code (No_Space));
      Assert_Equal (To_String (Error_Key (Fallback)), "error.io.no_space", "the last recorded cause wins");
      Reset;
      Assert_Equal (Key_For_Last (Fallback), Fallback, "Reset ends the operation's cause");
   end Test_Io_Error_Classifier;
