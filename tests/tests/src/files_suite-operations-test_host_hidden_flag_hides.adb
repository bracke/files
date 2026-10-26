separate (Files_Suite.Operations)
   procedure Test_Host_Hidden_Flag_Hides (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Dir      : constant String := Join (Root, "hiding");
      Flagged  : constant String := Join (Dir, "flagged.txt");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Marked   : Boolean := False;

      --  Mark Flagged hidden with the host's own tool; False where there is none.
      function Mark return Boolean is
         use type GNAT.OS_Lib.String_Access;
         Program : constant String :=
           (case Hostkit.Host.Current is
               when Hostkit.Host.Windows => "attrib",
               when Hostkit.Host.MacOS   => "chflags",
               when others               => "");
         Found   : GNAT.OS_Lib.String_Access :=
           (if Program = "" then null else GNAT.OS_Lib.Locate_Exec_On_Path (Program));
         Flag    : aliased String := (if Hostkit.Host.Current = Hostkit.Host.Windows then "+h" else "hidden");
         Name    : aliased String := Flagged;
         Success : Boolean := False;
      begin
         if Found /= null then
            GNAT.OS_Lib.Spawn (Found.all, [Flag'Unchecked_Access, Name'Unchecked_Access], Success);
            GNAT.OS_Lib.Free (Found);
         end if;
         return Success;
      end Mark;

      function Listed (Name : String) return Boolean is
        (for some Item of Load.Items => To_String (Item.Name) = Name);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_Binary_File (Join (Dir, "shown.txt"), "x");
      Write_Binary_File (Join (Dir, ".dotted"), "x");
      Write_Binary_File (Flagged, "x");
      Marked := Mark;
      --  Where the host has a hidden flag, the test marks one: a missing tool
      --  must fail here, not leave the host-flag half untested. (Linux has
      --  only dot files.)
      if Hostkit.Host.Current in Hostkit.Host.Windows | Hostkit.Host.MacOS then
         Assert (Marked, "the host's tool marks the file hidden");
      end if;

      Settings.Show_Hidden_Files := False;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Assert (Listed ("shown.txt") and then not Listed (".dotted"), "a dot file is hidden");
      Assert (not Marked or else not Listed ("flagged.txt"), "a file the host marks hidden is hidden");

      Settings.Show_Hidden_Files := True;
      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Assert (Listed (".dotted") and then Listed ("flagged.txt"), "Show Hidden Files lists both");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Hidden_Item_Count (Model),
         (if Marked then 2 else 1),
         "the hidden count includes what the host hides");
      for Item of Load.Items loop
         if To_String (Item.Name) = ".dotted" or else (Marked and then To_String (Item.Name) = "flagged.txt") then
            Assert (Item.Hidden, To_String (Item.Name) & " is marked hidden");
         end if;
      end loop;
   end Test_Host_Hidden_Flag_Hides;
