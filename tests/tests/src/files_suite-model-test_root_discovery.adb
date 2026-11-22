with Files.File_System.Roots.Testing;
with Files.File_System_Types;
with Files.File_System.Roots;
with Hostkit.Mounts;

separate (Files_Suite.Model)
   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Roots_A  : Files.Types.String_Vectors.Vector;
      Roots_B  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System_Types.Root_Entry_Vectors.Vector;
      Root_Status : Files.File_System.Roots.Testing.Root_Discovery_Diagnostics;

      --  The filesystem type the host's mount table gives Path, or "".
      function Filesystem_Type_Of (Path : String) return String is
      begin
         for Item of Hostkit.Mounts.Table loop
            if To_String (Item.Mount_Point) = Path then
               return To_String (Item.Filesystem_Type);
            end if;
         end loop;
         return "";
      end Filesystem_Type_Of;

   begin
      Reset_Root;
      Roots_A := Files.File_System.Roots.Testing.Available_Roots;
      Roots_B := Files.File_System.Roots.Testing.Available_Roots;
      Entries := Files.File_System.Roots.Available_Root_Entries;
      Root_Status := Files.File_System.Roots.Testing.Root_Discovery_Status;
      Assert (not Roots_A.Is_Empty, "available roots is never empty");
      Files_Suite.Support.Assert_Equal
        (Natural (Entries.Length),
         Natural (Roots_A.Length),
         "root metadata count matches root paths");
      Files_Suite.Support.Assert_Equal
        (Root_Status.Root_Count,
         Natural (Entries.Length),
         "root diagnostics count discovered roots");
      --  A mount container is listed only through what is mounted under it,
      --  never as a row of its own (check_all holds the exclusion's shape for
      --  hosts where no container is itself a mount point).
      for Item of Entries loop
         declare
            Path : constant String := To_String (Item.Path);
         begin
            Assert
              (Item.Kind /= Files.File_System_Types.Root_Mount
               or else Path not in "/mnt" | "/media" | "/run/media" | "/Volumes" | "/System/Volumes",
               "root discovery excludes mount container rows: " & Path);
         end;
      end loop;
      --  What each host roots its file system at: "/" where it has one
      --  (Linux, macOS), and the drives where it has none (Windows).
      if Hostkit.Mounts.Filesystem_Root /= "" then
         Assert
           ((for some Item of Entries =>
               Item.Kind = Files.File_System_Types.Root_Filesystem
               and then To_String (Item.Path) = Hostkit.Mounts.Filesystem_Root),
            "the filesystem root is listed as such");
      else
         Assert
           ((for some Item of Entries => Item.Kind = Files.File_System_Types.Root_Windows_Drive),
            "a host without a filesystem root lists its drives");
      end if;
      Files_Suite.Support.Assert_Equal
        (Natural (Roots_A.Length),
         Natural (Roots_B.Length),
         "available roots count is deterministic");
      for Index in 1 .. Natural (Roots_A.Length) loop
         Assert (To_String (Roots_A.Element (Index)) /= "", "available root path is non-empty");
         Files_Suite.Support.Assert_Equal
           (To_String (Entries.Element (Index).Path),
            To_String (Roots_A.Element (Index)),
            "root metadata path matches path projection");
         Assert (To_String (Entries.Element (Index).Label) /= "", "root metadata label is non-empty");
         Assert (To_String (Entries.Element (Index).Volume_Name) /= "", "root metadata volume name is non-empty");
         if Entries.Element (Index).Kind = Files.File_System_Types.Root_Mount then
            declare
               Path : constant String := To_String (Entries.Element (Index).Path);
               --  "" for a folder in a volumes folder that is no mount itself.
               Kind : constant String := Filesystem_Type_Of (Path);
            begin
               Assert
                 (Files.File_System.Roots.Testing.Is_User_Visible_Mount_Point (Path, Runtime_Gvfs => ""),
                  "root selector excludes system implementation mounts: " & Path);
               --  proc, sysfs, tmpfs, a snap's squashfs: no volume of the user's.
               Assert
                 (Kind = "" or else not Hostkit.Mounts.Is_Pseudo (Kind),
                  "root selector excludes pseudo filesystems: " & Path & " (" & Kind & ")");
            end;
         end if;
         Assert (Ada.Directories.Exists (To_String (Roots_A.Element (Index))), "available root path exists");
         Assert
           (Ada.Directories.Kind (To_String (Roots_A.Element (Index))) = Ada.Directories.Directory,
            "available root path is a directory");
         Files_Suite.Support.Assert_Equal
           (To_String (Roots_A.Element (Index)),
            To_String (Roots_B.Element (Index)),
            "available roots preserve deterministic order");
         for Other in Index + 1 .. Natural (Roots_A.Length) loop
            Assert
              (To_String (Roots_A.Element (Index)) /= To_String (Roots_A.Element (Other)),
               "available roots do not contain duplicates");
         end loop;
      end loop;
   end Test_Root_Discovery;
