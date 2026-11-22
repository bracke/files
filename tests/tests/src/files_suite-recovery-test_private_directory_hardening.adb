with Files_Suite.Support.Disk;
separate (Files_Suite.Recovery)
   procedure Test_Private_Directory_Hardening (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reset_Root;
      Assert
        (Files.IO.Private_Directories.Try_Create (Root) =
           Files.IO.Private_Directories.Collision,
         "private directory creation reports an existing pathname as a collision");
      declare
         Real_Directory : constant String := Join (Root, "private-real-directory");
         Linked_Path    : constant String := Join (Root, "private-linked-directory");
         Unexpected_Success : Boolean := False;
      begin
         Ada.Directories.Create_Directory (Real_Directory);
         if Files_Suite.Support.Disk.Create_Symlink (Real_Directory, Linked_Path) then
            begin
               Files.IO.Private_Directories.Ensure (Linked_Path);
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
            Files_Suite.Support.Disk.Link_Not_Made ("Test_Private_Directory_Hardening",
                                                    Files_Suite.Support.Disk.Symbolic_Link);
         end if;
         Ada.Directories.Delete_Directory (Real_Directory);
      end;
      declare
         Unexpected_Success : Boolean := False;
      begin
         begin
            declare
               Result : constant Files.IO.Private_Directories.Create_Result :=
                 Files.IO.Private_Directories.Try_Create
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
      --  A candidate the host refuses (not a collision) is abandoned before
      --  the failure propagates: what Prepare published for it is withdrawn.
      declare
         Prepared  : Natural := 0;
         Abandoned : Natural := 0;
         Raised    : Boolean := False;

         procedure Prepare (Path : String) is
            pragma Unreferenced (Path);
         begin
            Prepared := Prepared + 1;
         end Prepare;

         procedure Abandon (Path : String) is
            pragma Unreferenced (Path);
         begin
            Abandoned := Abandoned + 1;
         end Abandon;
      begin
         begin
            declare
               Made : constant String :=
                 Files.IO.Private_Directories.Create_Numbered
                   (Join (Root, "missing-parent"), "stage-",
                    Prepare => Prepare'Access, Abandon => Abandon'Access);
               pragma Unreferenced (Made);
            begin
               null;
            end;
         exception
            when Ada.Directories.Use_Error =>
               Raised := True;
         end;
         Assert (Raised, "a refused numbered directory raises");
         Files_Suite.Support.Assert_Equal (Prepared, 1, "the refused candidate was prepared once");
         Files_Suite.Support.Assert_Equal (Abandoned, 1, "and abandoned before the failure propagated");
      end;
   end Test_Private_Directory_Hardening;
