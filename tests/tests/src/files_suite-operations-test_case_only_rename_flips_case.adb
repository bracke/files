separate (Files_Suite.Operations)
   procedure Test_Case_Only_Rename_Flips_Case (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Image    : constant String := Join (Root, "ci.dmg");
      Mount    : constant String := Join (Root, "ci-volume");
      Attached : Boolean := False;

      function Run (Program : String; Arguments : GNAT.OS_Lib.Argument_List) return Boolean is
         use type GNAT.OS_Lib.String_Access;
         Found   : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Program);
         Success : Boolean := False;
      begin
         if Found /= null then
            GNAT.OS_Lib.Spawn (Found.all, Arguments, Success);
            GNAT.OS_Lib.Free (Found);
         end if;
         return Success;
      end Run;

      function Folds_Case (Directory : String) return Boolean is
         Probe : constant String := Join (Directory, "case-probe");
         Folds : Boolean;
      begin
         Write_Binary_File (Probe, "x");
         Folds := Ada.Directories.Exists (Join (Directory, "CASE-PROBE"));
         Ada.Directories.Delete_File (Probe);
         return Folds;
      end Folds_Case;

      procedure Detach is
         Detach_Arg : aliased String := "detach";
         Force_Arg  : aliased String := "-force";
         Point      : aliased String := Mount;
      begin
         if Attached and then Run ("hdiutil", [Detach_Arg'Unchecked_Access, Point'Unchecked_Access,
                                               Force_Arg'Unchecked_Access])
         then
            Attached := False;
         end if;
      end Detach;

      --  A folder on a case-insensitive volume, or Root where none can be had.
      function Insensitive_Folder return String is
      begin
         if Folds_Case (Root) or else Hostkit.Host.Current /= Hostkit.Host.MacOS then
            return Root;
         end if;
         declare
            Create : aliased String := "create";
            Size_F : aliased String := "-size";
            Size   : aliased String := "16m";
            Fs_F   : aliased String := "-fs";
            Fs     : aliased String := "Case-insensitive APFS";
            Name_F : aliased String := "-volname";
            Name   : aliased String := "FilesCaseTest";
            Path   : aliased String := Image;
            Attach : aliased String := "attach";
            No_Browse : aliased String := "-nobrowse";
            Point_F : aliased String := "-mountpoint";
            Point   : aliased String := Mount;
         begin
            Ada.Directories.Create_Path (Mount);
            if Run ("hdiutil", [Create'Unchecked_Access, Size_F'Unchecked_Access, Size'Unchecked_Access,
                                Fs_F'Unchecked_Access, Fs'Unchecked_Access, Name_F'Unchecked_Access,
                                Name'Unchecked_Access, Path'Unchecked_Access])
              and then Run ("hdiutil", [Attach'Unchecked_Access, Path'Unchecked_Access, No_Browse'Unchecked_Access,
                                        Point_F'Unchecked_Access, Point'Unchecked_Access])
            then
               Attached := True;
               return Mount;
            end if;
            return Root;
         end;
      end Insensitive_Folder;
   begin
      Reset_Root;
      declare
         Folder  : constant String := Insensitive_Folder;
         Folding : constant Boolean := Folds_Case (Folder);
         Model   : Files.Model.Window_Model;
         Load    : Files.File_System.Directory_Load_Result;
         Step    : Files.Operations.Operation_Result;
         Names   : Files.Types.String_Vectors.Vector;
      begin
         Assert (Hostkit.Host.Current /= Hostkit.Host.MacOS or else Folding,
                 "macOS runs the rename on a case-insensitive volume");
         Write_Binary_File (Join (Folder, "report.txt"), "the report");
         Load := Files.File_System.Load_Directory (Folder, Settings);
         Files.Model.Initialize (Model, Folder, Load.Items, Root);
         Select_Name (Model, "report.txt");
         Files.Model.Toggle_Rename (Model);
         Files.Model.Set_Rename_Text (Model, "Report.txt");
         Step := Files.Operations.Commit_Rename (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Step.Status,
            Files.Operations.Operation_Success,
            "the case-only rename succeeds" & (if Folding then " (case-insensitive volume)" else ""));
         Load := Files.File_System.Load_Directory (Folder, Settings);
         for Item of Load.Items loop
            Names.Append (Item.Name);
         end loop;
         Assert (Names.Contains (To_Unbounded_String ("Report.txt"))
                 and then not Names.Contains (To_Unbounded_String ("report.txt")),
                 "the folder now lists Report.txt, not report.txt");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Join (Folder, "Report.txt")),
            "the report",
            "the contents are intact");
         Ada.Directories.Delete_File (Join (Folder, "Report.txt"));
      end;
      Detach;
   exception
      when others =>
         Detach;
         raise;
   end Test_Case_Only_Rename_Flips_Case;
