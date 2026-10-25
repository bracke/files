separate (Files_Suite.Operations)
   procedure Test_Icon_Assets_Load_From_Disk (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Original_Cwd : constant String := Ada.Directories.Current_Directory;
      Trusted_Root : constant String := Files.Resources.Share_Root;
      Counterfeit_Cwd : constant String := Join (Root, "counterfeit-resource-cwd");
      Folder : Unbounded_String;

      procedure Restore is
      begin
         Ada.Directories.Set_Directory (Original_Cwd);
      exception
         when others => null;
      end Restore;

      --  Read the bundled folder.icon from disk. This confirms the runtime loads
      --  icon definitions from the .icon files (the single edit surface) rather
      --  than only the built-in copies, and that it sees the redesigned shapes.
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Join (Counterfeit_Cwd, "share/files/icons"));
      Write_Binary_File
        (Join (Counterfeit_Cwd, "share/files/icons/folder.icon"),
         "counterfeit current-directory icon");
      Ada.Directories.Set_Directory (Counterfeit_Cwd);
      Folder := To_Unbounded_String
        (Files.Icon_Assets.Disk_Icon_Asset ("folder", ""));
      Assert
        (Trusted_Root /= "",
         "bundled resources stay anchored to the executable, not the launch directory: a share root exists");
      Files_Suite.Support.Assert_Equal
        (Files.Resources.Share_Root,
         Trusted_Root,
         "bundled resources stay anchored to the executable, not the launch directory: unchanged by the cwd");
      Assert
        (Files.Resources.Share_Root /=
           Ada.Directories.Full_Name ("share"),
         "bundled resources stay anchored to the executable, not the launch directory: not the cwd's share");
      Restore;
      Assert (Length (Folder) > 0, "the bundled folder.icon is read from disk");
      Assert (Ada.Strings.Fixed.Index (To_String (Folder), "files-icon-v1") > 0,
              "the disk icon carries the files-icon-v1 header");
      Assert (Ada.Strings.Fixed.Index (To_String (Folder), "grid=32") > 0,
              "the disk icon uses the finer 32-unit grid");
      Assert (Ada.Strings.Fixed.Index (To_String (Folder), "tri=") > 0,
              "the disk icon uses triangle primitives");
      Assert
        (Files.Icon_Assets.Disk_Icon_Asset ("../settings", "") = ""
         and then Files.Icon_Assets.Disk_Icon_Asset
           ("folder", "../../untrusted-theme") = "",
         "icon assets reject path traversal and unknown theme identifiers");
   exception
      when others => Restore; raise;
   end Test_Icon_Assets_Load_From_Disk;
