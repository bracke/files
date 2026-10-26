separate (Files_Suite.Operations)
   --  A volume's trash (.Trash-$uid), its files/ and info/, and what is in
   --  them may not be trashed: they would go into themselves.
   procedure Test_Trash_Refuses_Volume_Trash (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Uid : Natural;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      --  The freedesktop trash, also on macOS (whose native trash has no
      --  folder of ours to guard).
      Files_Suite.Support.Save (Environment, "FILES_TRASH_BACKEND");
      Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");
      if Hostkit.Host.Current = Hostkit.Host.Windows or else not Hostkit.Process.Current_User_Id (Uid) then
         Files_Suite.Support.Skip ("Test_Trash_Refuses_Volume_Trash", "Windows has no freedesktop volume trash");
         return;
      end if;
      Reset_Root;
      declare
         Image : constant String := Natural'Image (Uid);
         Top   : constant String := Join (Root, "volume-top");
         Base  : constant String := Join (Top, ".Trash-" & Image (Image'First + 1 .. Image'Last));
         Item  : constant String := Join (Join (Base, "files"), "item.txt");
         Plain : constant String := Join (Root, ".Trashy");

         procedure Refused (Path : String) is
         begin
            Assert (not Files.File_System.Move_To_Trash_Preflight (Path).Success,
                    "a volume trash part is not trashed: " & Path);
         end Refused;
      begin
         --  A volume's top only its owner writes to (the umask may have
         --  left the test root group-writable).
         Ada.Directories.Create_Path (Top);
         Assert (Files.File_System.Set_Permissions (Top, 8#755#).Success, "the top is its owner's");
         Ada.Directories.Create_Path (Join (Base, "files"));
         Ada.Directories.Create_Path (Join (Base, "info"));
         Ada.Directories.Create_Path (Plain);
         Write_File (Item, "trashed");
         Refused (Base);
         Refused (Join (Base, "files"));
         Refused (Join (Base, "info"));
         Refused (Item);
         Assert (Files.File_System.Move_To_Trash_Preflight (Plain).Success,
                 "a folder that only looks like one is trashed as usual");
      end;
      Reset_Root;
   end Test_Trash_Refuses_Volume_Trash;
