separate (Files_Suite.Model)
   procedure Test_Root_Discovery (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Target   : constant String := Join (Root, "selected-root");
      Roots_A  : Files.Types.String_Vectors.Vector;
      Roots_B  : Files.Types.String_Vectors.Vector;
      Entries  : Files.File_System.Root_Entry_Vectors.Vector;
      Root_Status : Files.File_System.Root_Discovery_Diagnostics;

      function Starts_With
        (Text   : String;
         Prefix : String)
         return Boolean is
      begin
         return Text'Length >= Prefix'Length
           and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
      end Starts_With;

      function Is_User_Visible_Mount_Point (Path : String) return Boolean is
      begin
         return Path = "/"
           or else Path = "/mnt"
           or else Starts_With (Path, "/mnt/")
           or else Path = "/media"
           or else Starts_With (Path, "/media/")
           or else Path = "/run/media"
           or else Starts_With (Path, "/run/media/")
           or else Path = "/Volumes"
           or else Starts_With (Path, "/Volumes/")
           or else Path = "/System/Volumes"
           or else Starts_With (Path, "/System/Volumes/");
      end Is_User_Visible_Mount_Point;

   begin
      Reset_Root;
      Ada.Directories.Create_Path (Target);
      Write_File (Join (Target, "inside.txt"));
      Roots_A := Files.File_System.Available_Roots;
      Roots_B := Files.File_System.Available_Roots;
      Entries := Files.File_System.Available_Root_Entries;
      Root_Status := Files.File_System.Root_Discovery_Status;
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
      Assert
        (Files_Suite.Repository.Source_Contains ("function Is_Mount_Container")
         and then Files_Suite.Repository.Source_Contains ("return not Is_Mount_Container"),
         "root discovery excludes mount container rows");
      Files_Suite.Support.Assert_Equal
        (Natural (Roots_A.Length),
         Natural (Roots_B.Length),
         "available roots count is deterministic");
      for Index in 1 .. Natural (Roots_A.Length) loop
         declare
            Detail : constant Files.File_System.Root_Volume_Details :=
              Files.File_System.Root_Volume_Details_For (Entries.Element (Index));
         begin
            Files_Suite.Support.Assert_Equal
              (To_String (Detail.Path),
               To_String (Entries.Element (Index).Path),
               "root volume details preserve root path");
            Assert
              (To_String (Detail.Native_Api_Name) = "none"
               or else To_String (Detail.Native_Api_Name) = "proc.mounts"
               or else To_String (Detail.Native_Api_Name) = "proc.mounts+sysfs"
               or else To_String (Detail.Native_Api_Name) = "statvfs"
               or else To_String (Detail.Native_Api_Name) = "statvfs+proc.mounts"
               or else To_String (Detail.Native_Api_Name) = "statvfs+proc.mounts+sysfs"
               or else To_String (Detail.Native_Api_Name) = "sysfs",
               "root volume details name adapter");
            if To_String (Detail.Filesystem_Type) /= "" then
               Assert (To_String (Detail.Source_Device) /= "", "root volume details include mount source");
               Assert (To_String (Detail.Mount_Options) /= "", "root volume details include mount options");
            end if;
            Files_Suite.Support.Assert_Equal
              (Detail.Capacity_Known,
               Detail.Free_Known,
               "root volume size flags are consistent");
            if Detail.Capacity_Known then
               Assert (Detail.Capacity_Bytes > 0, "known root volume capacity is positive");
               Assert (Detail.Free_Bytes >= 0, "known root volume free space is non-negative");
               Assert (Detail.Free_Bytes <= Detail.Capacity_Bytes, "known root volume free space fits capacity");
               Assert (Detail.Read_Only_Known, "known root volume capacity includes read-only metadata");
               Assert (Detail.Name_Max_Known, "known root volume capacity includes filename limit metadata");
               Assert (Detail.Name_Max > 0, "known root volume filename limit is positive");
            end if;
            if Detail.Inode_Count_Known then
               Assert (Detail.Inode_Count > 0, "known root volume inode count is positive");
               Assert (Detail.Free_Inode_Known, "known root volume inode count includes free inode count");
               Assert
                 (Detail.Free_Inode_Count <= Detail.Inode_Count,
                  "known root volume free inode count fits inode count");
            end if;
            Assert
              (Detail.Uses_Platform_Detail =
               (Detail.Capacity_Known
                or else Detail.Inode_Count_Known
                or else Detail.Read_Only_Known
                or else Detail.Name_Max_Known
                or else Detail.Removable_Known
                or else To_String (Detail.Filesystem_Type) /= ""),
               "root volume details platform flag follows filesystem type availability");
         end;
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
