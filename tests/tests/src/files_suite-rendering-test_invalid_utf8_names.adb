separate (Files_Suite.Rendering)
   --  POSIX file names are bytes: one that is not valid UTF-8 ("bad\xFF.txt")
   --  must list, render (snapshot, frame, accessibility tree), rename and
   --  delete like any other. Hosts whose file systems refuse such a name skip,
   --  and so does Windows, whose UTF-16 names translate the bytes on the way in.
   procedure Test_Invalid_UTF8_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Bad      : constant String := "bad" & Character'Val (16#FF#) & Character'Val (16#C3#) & ".txt";
      Bad_Path : constant String := Files_Suite.Support.Root & "/" & Bad;
      Good     : constant String := Files_Suite.Support.Root & "/good.txt";
      Created  : Boolean := True;
   begin
      if Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows) then
         Files_Suite.Support.Skip
           ("Test_Invalid_UTF8_Names",
            "Hostkit.Host.""="" (Hostkit.Host.Current, Hostkit.Host.Windows)");
         return;
      end if;
      Files_Suite.Support.Reset_Root;
      begin
         Files_Suite.Support.Write_File (Bad_Path, "bytes");
      exception
         when others =>
            Created := False;
      end;
      if not Created or else not Ada.Directories.Exists (Bad_Path) then
         Files_Suite.Support.Skip
           ("Test_Invalid_UTF8_Names",
            "not Created or else not Ada.Directories.Exists (Bad_Path)");
         return;
      end if;
      Files_Suite.Support.Write_File (Files_Suite.Support.Root & "/plain.txt", "x");

      declare
         Load   : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Files_Suite.Support.Root, Settings);
         Listed : Boolean := False;
         Model  : Files.Model.Window_Model;
      begin
         Assert (Load.Success, "a directory holding a non-UTF-8 name loads");
         for Item of Load.Items loop
            Listed := Listed or else Ada.Strings.Unbounded.To_String (Item.Name) = Bad;
         end loop;
         Assert (Listed, "the non-UTF-8 name is listed with its bytes");
         Files.Model.Navigate_To (Model, Files_Suite.Support.Root, Load.Items);
         declare
            Snapshot : constant View_Snapshot := Build_Snapshot (Model, Settings);
            Frame    : constant Frame_Commands :=
              Build_Frame_Commands (Snapshot, Width => 1200, Height => 800, Line_Height => 20);
            Tree     : constant A11ykit.Tree.Accessibility_Tree := Files.Accessibility.To_A11ykit_Tree (Frame);
         begin
            Files_Suite.Support.Assert_Equal (Natural (Snapshot.Items.Length), 2, "both items reach the snapshot");
            Assert (not Tree.Nodes.Is_Empty, "the accessibility tree builds over a non-UTF-8 name");
         end;
      end;

      Assert (Files.File_System.Rename_Item (Bad_Path, Good).Success, "a non-UTF-8 name renames to a valid one");
      Assert (Ada.Directories.Exists (Good) and then not Ada.Directories.Exists (Bad_Path), "the rename moved it");
      declare
         Back : constant Files.File_System.Mutation_Result := Files.File_System.Rename_Item (Good, Bad_Path);
      begin
         Assert (Back.Success, "and renames back to the non-UTF-8 name: "
                 & Ada.Strings.Unbounded.To_String (Back.Error_Key));
      end;
      --  Copied and moved into another folder with its name kept: the name
      --  exists, so only what the destination cannot hold is refused.
      declare
         Into    : constant String := Files_Suite.Support.Root & "/into";
         Sources : Files.Types.String_Vectors.Vector;
      begin
         Ada.Directories.Create_Path (Into);
         Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String (Bad_Path));
         declare
            Plan : constant Files.File_System.Drop_Import_Result :=
              Files.File_System.Plan_Drop_Import (Sources, Into, Files.File_System.Drop_Copy);
         begin
            Assert (Plan.Plans.First_Element.Valid, "a non-UTF-8 name can be copied: "
                    & Ada.Strings.Unbounded.To_String (Plan.Error_Key));
            Assert (Files.File_System.Execute_Drop_Import (Plan.Plans).Success, "the copy runs");
            Assert (Ada.Directories.Exists (Into & "/" & Bad), "the copy keeps the name's bytes");
         end;
      end;
      Assert (Files.File_System.Delete_Permanently (Bad_Path).Success, "a non-UTF-8 name deletes");
      Assert (not Ada.Directories.Exists (Bad_Path), "the delete removed it");
      Files_Suite.Support.Reset_Root;
   end Test_Invalid_UTF8_Names;
