separate (Files_Suite.Operations)
   --  A duplicate of a name already at the filesystem's 255-byte limit is
   --  cut to fit, its "(copy)" marker and extension kept whole, rather than
   --  refused by the disk as too long.
   procedure Test_Generated_Names_Fit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Step     : Files.Operations.Operation_Result;
      Load     : Files.File_System.Directory_Load_Result;
      Stem     : constant String (1 .. 251) := [others => 'n'];
      Name     : constant String := Stem & ".txt";
      Found    : Boolean := False;
   begin
      Reset_Root;
      --  Written short, then renamed through hostkit, whose paths take the
      --  long form on Windows: Ada's own file I/O cannot open a 255-byte name
      --  under the test root there.
      Write_Binary_File (Join (Root, "short.txt"), "bytes");
      Assert (Hostkit.Fs.Move_No_Replace (Join (Root, "short.txt"), Join (Root, Name)),
              "the fixture takes its 255-byte name");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Operations.Clear_Undo (Model);
      Files.Model.Set_Background_Transfers (Model, False);
      Select_Name (Model, Name);
      Step := Files.Operations.Duplicate_Selected (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operations.Operation_Success, "a 255-byte name can be duplicated");
      Load := Files.File_System.Load_Directory (Root, Settings);
      for Item of Load.Items loop
         declare
            Copy : constant String := To_String (Item.Name);
         begin
            if Copy /= Name then
               Found := True;
               Assert (Copy'Length <= 255, "the duplicate's name fits: " & Copy'Length'Image & " bytes");
               Assert (Copy'Length >= 4 and then Copy (Copy'Last - 3 .. Copy'Last) = ".txt",
                       "the duplicate keeps the extension");
               Assert (Ada.Strings.Fixed.Index (Copy, "(") > 0, "and its copy marker");
            end if;
         end;
      end loop;
      Assert (Found, "the duplicate is listed");
   end Test_Generated_Names_Fit;
