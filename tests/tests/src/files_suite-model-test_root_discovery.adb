with Hostkit.Mounts;
with Files.File_System.Testing;
separate (Files_Suite.Model)
   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Roots_A  : Files.Types.String_Vectors.Vector;
      Roots_B  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Root_Status : Files.File_System.Testing.Root_Discovery_Diagnostics;

      function Starts_With
        (Text   : String;
         Prefix : String)
         return Boolean is
      begin
         return Text'Length >= Prefix'Length
           and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      --  "/", a host volume folder, or inside one.
      function Is_User_Visible_Mount_Point (Path : String) return Boolean is
      begin
         if Path = "/" then
            return True;
         end if;
         for Place of Hostkit.Mounts.Volume_Places loop
            if Path = To_String (Place.Path) or else Starts_With (Path, To_String (Place.Path) & "/") then
               return True;
            end if;
         end loop;
         return False;
      end Is_User_Visible_Mount_Point;

   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Roots_A := Files.File_System.Testing.Available_Roots;
      Roots_B := Files.File_System.Testing.Available_Roots;
      Entries := Files.File_System.Available_Root_Entries;
      Root_Status := Files.File_System.Testing.Root_Discovery_Status;
      Assert (not Roots_A.Is_Empty, "available roots is never empty");
      Files_Suite.Support.Assert_Equal
        (Natural (Entries.Length),
         Natural (Roots_A.Length),
         "root metadata count matches root paths");
      Files_Suite.Support.Assert_Equal
        (Root_Status.Root_Count,
         Natural (Entries.Length),
         "root diagnostics count discovered roots");
      Files_Suite.Support.Assert_Equal
        (Root_Status.Ready_Count,
         Natural (Entries.Length),
         "root diagnostics count ready roots");
      --  A mount container is listed only through what is mounted under it,
      --  never as a row of its own (check_all holds the exclusion's shape for
      --  hosts where no container is itself a mount point).
      for Item of Entries loop
         declare
            Path : constant String := To_String (Item.Path);
         begin
            Assert
              (Item.Kind /= Files.File_System.Root_Mount
               or else Path not in "/mnt" | "/media" | "/run/media" | "/Volumes" | "/System/Volumes",
               "root discovery excludes mount container rows: " & Path);
         end;
      end loop;
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
         Assert (Entries.Element (Index).Ready = Files.File_System.Root_Ready, "root metadata marks roots ready");
         case Entries.Element (Index).Kind is
            when Files.File_System.Root_Filesystem
               | Files.File_System.Root_Home
               | Files.File_System.Root_Current
               | Files.File_System.Root_Mount
               | Files.File_System.Root_User_Mount
               | Files.File_System.Root_Network_Mount
               | Files.File_System.Root_Windows_Drive
               | Files.File_System.Root_Favorite =>
               null;
         end case;
         if Entries.Element (Index).Kind = Files.File_System.Root_Mount then
            Assert
              (Is_User_Visible_Mount_Point (To_String (Entries.Element (Index).Path)),
               "root selector excludes system implementation mounts");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|tmpfs"),
               0,
               "root selector excludes tmpfs mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|proc"),
               0,
               "root selector excludes proc mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|sysfs"),
               0,
               "root selector excludes sysfs mounts from proc metadata");
            Files_Suite.Support.Assert_Equal
              (Ada.Strings.Fixed.Index (To_String (Entries.Element (Index).Label), "|squashfs"),
               0,
               "root selector excludes snap package mounts from proc metadata");
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
