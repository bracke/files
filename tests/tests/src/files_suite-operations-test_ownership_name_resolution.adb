separate (Files_Suite.Operations)
   procedure Test_Ownership_Name_Resolution (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Account_Id;
      Found : Boolean := False;
      Id    : Files.Types.Account_Id := 0;
   begin
      if not Files.File_System.Supports_Ownership then
         Files_Suite.Support.Skip
           ("Test_Ownership_Name_Resolution", "this host has no POSIX owner and group to change");
         return;
      end if;

      if Files.Platform.Current_API_Profile.Adapter
           = Files.File_System.Native_Adapter_Windows
      then
         --  There is no "root" on Windows and no uid 0: an account is a SID, and
         --  the number the interface hands out is that SID's relative identifier.
         --  So assert the property that actually holds -- the identity of a file
         --  we just made round-trips through a name and back.
         declare
            Owned : constant String := Join (Root, "owned.txt");
            Uid, Gid : Files.Types.Account_Id := 0;
            Avail    : Boolean := False;
            Round    : Files.Types.Account_Id := 0;
         begin
            Reset_Root;
            Write_File (Owned, "owned");
            Files.File_System.Ownership_Of (Owned, Uid, Gid, Avail);
            Assert (Avail, "a file we just created has an owner");

            declare
               Name : constant String := Files.File_System.User_Name_For_Id (Uid);
            begin
               Assert (Name /= "", "the owning identity resolves to a name");
               Round := Files.File_System.User_Id_For_Name (Name, Found);
               Assert (Found and then Round = Uid,
                       "that name resolves back to the same identity");
            end;
         end;
      else
         Id := Files.File_System.User_Id_For_Name ("root", Found);
         Assert (Found and then Id = 0, "user name root resolves to uid 0");

         Id := Files.File_System.Group_Id_For_Name ("root", Found);
         --  The root group is gid 0 on Linux; on some systems it is named
         --  "wheel", so accept a successful resolution to 0 or a not-found result
         --  rather than asserting a fixed gid that may vary by distribution.
         if Found then
            Files_Suite.Support.Assert_Equal (Id, 0, "group name root, when present, resolves to gid 0");
         end if;
      end if;

      Id := Files.File_System.User_Id_For_Name ("no_such_user_xyzzy_42", Found);
      Assert (not Found and then Id = 0, "a bogus user name reports Found => False");

      Id := Files.File_System.Group_Id_For_Name ("no_such_group_xyzzy_42", Found);
      Assert (not Found and then Id = 0, "a bogus group name reports Found => False");

      --  Reverse resolution: uid 0 is root on any normal Linux system; gid 0 is
      --  "root" or "wheel" depending on distribution, so only assert non-empty.
      --  Neither number means anything on Windows.
      if Files.Platform.Current_API_Profile.Adapter
           /= Files.File_System.Native_Adapter_Windows
      then
         Files_Suite.Support.Assert_Equal (Files.File_System.User_Name_For_Id (0), "root", "uid 0 resolves to root");
         Assert (Files.File_System.Group_Name_For_Id (0) /= "", "gid 0 resolves to a group name");
      end if;
      Files_Suite.Support.Assert_Equal
        (Files.File_System.User_Name_For_Id (2_000_000_000),
         "",
         "an unassigned uid resolves to the empty string");
      Files_Suite.Support.Assert_Equal
        (Files.File_System.Group_Name_For_Id (2_000_000_000),
         "",
         "an unassigned gid resolves to the empty string");
   end Test_Ownership_Name_Resolution;
