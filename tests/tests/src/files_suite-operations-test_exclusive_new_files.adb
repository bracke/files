with Hostkit.Metadata;
separate (Files_Suite.Operations)
   procedure Test_Exclusive_New_Files (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target : constant String := Join (Root, "target");
      Link : constant String := Join (Root, "link");
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      if Create_Symlink (Target, Link) then
         Mutation := Files.File_System.Create_Empty_File (Link);
         Assert (not Mutation.Success, "creation preserves a dangling link and its target: refused");
         Assert (Hostkit.Fs.Is_Link (Link), "creation preserves a dangling link and its target: link kept");
         Assert (not Ada.Directories.Exists (Target), "creation preserves a dangling link and its target: no target");
         Write_Binary_File (Target, "existing bytes");
         Mutation := Files.File_System.Create_Empty_File (Link);
         Assert (not Mutation.Success and then File_Is (Target, "existing bytes"),
                 "creation preserves a live symbolic link target");
      else
         Link_Not_Made ("Test_Exclusive_New_Files");
         Write_Binary_File (Target, "existing bytes");
      end if;
      Mutation := Files.File_System.Create_Empty_File (Target);
      Assert (not Mutation.Success and then File_Is (Target, "existing bytes"),
              "creation never truncates an existing regular file");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "new"));
      Assert (Mutation.Success and then Ada.Directories.Size (Join (Root, "new")) = 0,
              "exclusive creation still creates an empty new file");
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Skip ("Test_Exclusive_New_Files", "needs native POSIX mode bits");
      else
         declare
            Parent : constant String := Join (Root, "read-only-parent");
            use type Files.Types.Account_Id;
            User_Id, Group_Id : Files.Types.Account_Id;
            Available : Boolean;
         begin
            Ada.Directories.Create_Directory (Parent);
            Hostkit.Metadata.File_Ownership (Parent, User_Id, Group_Id, Available);
            if Available and then User_Id /= 0 then
               Assert (Files.File_System.Set_Permissions (Parent, 8#555#).Success, "prepare a read-only parent");
               Mutation := Files.File_System.Create_Empty_File (Join (Parent, "child"));
               Assert (not Mutation.Success,
                       "a creation access failure reports permission denied without claiming a collision: refused");
               Files_Suite.Support.Assert_Equal
                 (To_String (Mutation.Error_Key),
                  "error.io.denied",
                  "a creation access failure reports permission denied without claiming a collision: error key");
               Assert (not Ada.Directories.Exists (Join (Parent, "child")),
                       "a creation access failure reports permission denied without claiming a collision: "
                       & "nothing created");
            else
               Skip ("Test_Exclusive_New_Files", "root ignores a read-only directory");
            end if;
            Mutation := Files.File_System.Set_Permissions (Parent, 8#755#);
         exception
            when others =>
               Mutation := Files.File_System.Set_Permissions (Parent, 8#755#);
               raise;
         end;
      end if;
   end Test_Exclusive_New_Files;
