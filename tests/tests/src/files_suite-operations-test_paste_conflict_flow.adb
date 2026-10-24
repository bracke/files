separate (Files_Suite.Operations)
   procedure Test_Paste_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "conflict-src");
      Dest_Dir : constant String := Join (Root, "conflict-dest");

      --  Read a file, dropping the line terminator Write_File leaves behind so the
      --  payload compares cleanly against the written text. That terminator is
      --  CRLF on Windows, not LF, and dropping only the LF left a stray CR that
      --  made every content comparison fail there.
      function Read (Path : String) return String is
         Raw  : constant String := Project_Tools.Files.Read_Raw_File (Path);
         Last : Natural := Raw'Last;
      begin
         if Last >= Raw'First and then Raw (Last) = ASCII.LF then
            Last := Last - 1;
         end if;
         if Last >= Raw'First and then Raw (Last) = ASCII.CR then
            Last := Last - 1;
         end if;
         return Raw (Raw'First .. Last);
      end Read;

      procedure Arm_Model
        (Model : out Files.Model.Window_Model;
         Names : Files.Types.String_Vectors.Vector)
      is
         Load  : Files.File_System.Directory_Load_Result;
         Paths : Files.Types.String_Vectors.Vector;
      begin
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         for Name of Names loop
            Paths.Append (To_Unbounded_String (Join (Src_Dir, To_String (Name))));
         end loop;
         Files.Model.Set_Clipboard (Model, Paths, Files.Model.Clipboard_Copy);
      end Arm_Model;

      One_File : Files.Types.String_Vectors.Vector;
      Two_File : Files.Types.String_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;
      Resolved : Files.Operations.Operation_Result;
   begin
      One_File.Append (To_Unbounded_String ("a.txt"));
      Two_File.Append (To_Unbounded_String ("a.txt"));
      Two_File.Append (To_Unbounded_String ("b.txt"));

      --  Replace: the paste overwrites the destination.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      pragma Unreferenced (Routed);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "a colliding paste arms the conflict dialog");
      Assert (Files.Model.Paste_Conflict_Name (Model) = "a.txt", "the dialog names the colliding item");
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, False);
      Assert (Resolved.Status = Files.Operations.Operation_Success, "replace resolves successfully");
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "SRC",
              "replace overwrites the destination with the source; destination holds "
              & Read (Join (Dest_Dir, "a.txt")));

      --  Skip: the destination is left untouched and the source remains.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Skip, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "skip clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "skip leaves the destination untouched");
      Assert (Ada.Directories.Exists (Join (Src_Dir, "a.txt")), "skip leaves the source in place");

      --  Rename: a uniquely named copy is created and the original is kept.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "rename clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "rename keeps the original destination");
      Assert (Read (Join (Dest_Dir, "a 2.txt")) = "SRC", "rename writes the source under a unique name");

      --  Undo of the completed rename paste removes the created copy.
      Routed := Files.Controller.Execute_Command (Files.Commands.Undo_Command, Model, Settings);
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")), "undo removes the pasted copy");
      Assert (Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "undo keeps the pre-existing original");

      --  Apply-to-all: one decision resolves every remaining conflict.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRCA");
      Write_File (Join (Src_Dir, "b.txt"), "SRCB");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Write_File (Join (Dest_Dir, "b.txt"), "DEST");
      Arm_Model (Model, Two_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Assert (Files.Model.Paste_Conflict_Is_Active (Model), "two collisions arm the dialog");
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, True);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "apply-to-all resolves both without a second prompt");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "SRCA", "apply-to-all replaces the first item");
      Assert (Read (Join (Dest_Dir, "b.txt")) = "SRCB", "apply-to-all replaces the second item");

      --  Cancel: the whole paste aborts with no filesystem change.
      Reset_Root;
      Ada.Directories.Create_Path (Src_Dir);
      Ada.Directories.Create_Path (Dest_Dir);
      Write_File (Join (Src_Dir, "a.txt"), "SRC");
      Write_File (Join (Dest_Dir, "a.txt"), "DEST");
      Arm_Model (Model, One_File);
      Routed := Files.Controller.Execute_Command (Files.Commands.Paste_Items_Command, Model, Settings);
      Resolved :=
        Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Cancel, False);
      Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "cancel clears the dialog");
      Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "cancel changes nothing at the destination");
      Assert (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")), "cancel writes no copy");
      Assert (Files.Model.Clipboard_Has_Items (Model), "cancel keeps the clipboard for a retry");
   end Test_Paste_Conflict_Flow;
