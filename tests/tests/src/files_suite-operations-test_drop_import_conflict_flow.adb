separate (Files_Suite.Operations)
   procedure Test_Drop_Import_Conflict_Flow (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Src_Dir  : constant String := Join (Root, "dropc-src");
      Dest_Dir : constant String := Join (Root, "dropc-dest");
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;

      --  The terminator Write_File leaves is CRLF on Windows, not LF.
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

      --  Reset the fixture and initialize the model on the destination directory
      --  (the drop target), returning the single external source to drop.
      function Prepare return Files.Types.String_Vectors.Vector is
         Load    : Files.File_System.Directory_Load_Result;
         Sources : Files.Types.String_Vectors.Vector;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, "a.txt"), "SRC");
         Write_File (Join (Dest_Dir, "a.txt"), "DEST");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Sources.Append (To_Unbounded_String (Join (Src_Dir, "a.txt")));
         return Sources;
      end Prepare;
   begin
      --  Replace: the dropped source overwrites the colliding destination.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Assert
           (Routed.Operation.Status = Files.Operations.Operation_Success,
            "an armed drop conflict reports success without writing");
         Assert (Files.Model.Paste_Conflict_Is_Active (Model), "a colliding drop arms the conflict dialog");
         Assert (Files.Model.Paste_Conflict_Name (Model) = "a.txt", "the drop dialog names the colliding item");
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Replace, False);
         Assert (not Files.Model.Paste_Conflict_Is_Active (Model), "resolving the drop clears the dialog");
         Assert (Read (Join (Dest_Dir, "a.txt")) = "SRC",
              "replace overwrites the destination with the dropped source; destination holds "
              & Read (Join (Dest_Dir, "a.txt")));
      end;

      --  Skip: the destination and the source both stay untouched.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Skip, False);
         Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "skip leaves the drop destination untouched");
         Assert (Ada.Directories.Exists (Join (Src_Dir, "a.txt")), "skip leaves the dropped source in place");
      end;

      --  Rename: a uniquely named copy is written, then undo removes it.
      declare
         Sources : constant Files.Types.String_Vectors.Vector := Prepare;
      begin
         Routed := Files.Controller.Handle_Drop_Import (Model, Settings, Sources);
         Routed.Operation :=
           Files.Operations.Resolve_Paste_Conflict (Model, Settings, Files.Operations.Choice_Rename, False);
         Assert (Read (Join (Dest_Dir, "a.txt")) = "DEST", "rename keeps the original drop destination");
         Assert (Read (Join (Dest_Dir, "a 2.txt")) = "SRC", "rename writes the dropped source under a unique name");
         Routed.Operation := Complete_Operation (Model, Settings, Files.Operations.Undo_Last (Model, Settings));
         Assert
           (not Ada.Directories.Exists (Join (Dest_Dir, "a 2.txt")),
            "undo reverses a completed drag-and-drop import");
         Assert (Ada.Directories.Exists (Join (Dest_Dir, "a.txt")), "undo keeps the pre-existing original");
      end;

      --  A drag-and-drop move must not clear an unrelated clipboard selection.
      declare
         Load      : Files.File_System.Directory_Load_Result;
         Sources   : Files.Types.String_Vectors.Vector;
         Clip      : Files.Types.String_Vectors.Vector;
      begin
         Reset_Root;
         Ada.Directories.Create_Path (Src_Dir);
         Ada.Directories.Create_Path (Dest_Dir);
         Write_File (Join (Src_Dir, "m.txt"), "MOVE");
         Write_File (Join (Dest_Dir, "clip.txt"), "CLIP");
         Load := Files.File_System.Load_Directory (Dest_Dir, Settings);
         Files.Model.Initialize (Model, Dest_Dir, Load.Items, Root);
         Clip.Append (To_Unbounded_String (Join (Dest_Dir, "clip.txt")));
         Files.Model.Set_Clipboard (Model, Clip, Files.Model.Clipboard_Copy);
         Sources.Append (To_Unbounded_String (Join (Src_Dir, "m.txt")));
         Routed :=
           Files.Controller.Handle_Drop_Import (Model, Settings, Sources, Files.File_System.Drop_Move);
         Assert
           (Routed.Operation.Status = Files.Operations.Operation_Success,
            "a collision-free dropped move succeeds");
         Assert
           (Ada.Directories.Exists (Join (Dest_Dir, "m.txt")),
            "a collision-free dropped move imports the source");
         Assert (not Ada.Directories.Exists (Join (Src_Dir, "m.txt")), "a dropped move removes the source");
         Assert
           (Files.Model.Clipboard_Has_Items (Model),
            "a dropped move does not clear the unrelated clipboard selection");
      end;
   end Test_Drop_Import_Conflict_Flow;
