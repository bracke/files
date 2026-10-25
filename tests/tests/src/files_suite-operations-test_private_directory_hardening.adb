separate (Files_Suite.Operations)
   procedure Test_Private_Directory_Hardening (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;
      Assert
        (Files.Private_Directories.Try_Create (Root) =
           Files.Private_Directories.Collision,
         "private directory creation reports an existing pathname as a collision");
      declare
         Real_Directory : constant String := Join (Root, "private-real-directory");
         Linked_Path    : constant String := Join (Root, "private-linked-directory");
         Unexpected_Success : Boolean := False;
      begin
         Ada.Directories.Create_Directory (Real_Directory);
         if Files_Suite.Support.Create_Symlink (Real_Directory, Linked_Path) then
            begin
               Files.Private_Directories.Ensure (Linked_Path);
               Unexpected_Success := True;
            exception
               when Ada.Directories.Use_Error =>
                  null;
            end;
            Assert
              (not Unexpected_Success,
               "private-directory hardening rejects a link without removing it or its target: refused");
            Assert
              (Hostkit.Fs.Is_Link (Linked_Path),
               "private-directory hardening rejects a link without removing it or its target: link kept");
            Assert
              (Ada.Directories.Exists (Real_Directory),
               "private-directory hardening rejects a link without removing it or its target: target kept");
            declare
               Removed : constant Boolean := Hostkit.Fs.Delete_Link (Linked_Path);
               pragma Unreferenced (Removed);
            begin
               null;
            end;
         else
            Files_Suite.Support.Link_Not_Made ("Test_Private_Directory_Hardening", Files_Suite.Support.Symbolic_Link);
         end if;
         Ada.Directories.Delete_Directory (Real_Directory);
      end;
      declare
         Unexpected_Success : Boolean := False;
      begin
         begin
            declare
               Result : constant Files.Private_Directories.Create_Result :=
                 Files.Private_Directories.Try_Create
                   (Join (Join (Root, "missing-parent"), "candidate"));
               pragma Unreferenced (Result);
            begin
               Unexpected_Success := True;
            end;
         exception
            when Ada.Directories.Use_Error => null;
         end;
         Assert
           (not Unexpected_Success,
            "private directory setup failures are not misreported as collisions");
      end;
   end Test_Private_Directory_Hardening;
